use std::time::{Duration, Instant};

// 缩短设备端采样等待，保留传输超时供设备正常返回响应。
pub(super) const CAPTURE_WAIT_MS: u32 = 1_000;

pub(super) fn sample_result(
    status: u8,
    remaining: u8,
    on_sample: &mut dyn FnMut(),
) -> Result<bool, String> {
    match status {
        0x00 => {
            on_sample();
            Ok(remaining > 0)
        }
        // 没有手指或还未抬起手指，本轮没有有效样本，继续原录入。
        0x0d | 0x0e => Ok(true),
        _ => Err(format!("指纹采集失败（状态 {status:#04x}），请重试")),
    }
}

pub(super) fn check_cancelled(cancelled: &dyn Fn() -> bool) -> Result<(), String> {
    if cancelled() {
        Err("指纹录入已取消".into())
    } else {
        Ok(())
    }
}

pub(super) fn run(
    cancelled: &dyn Fn() -> bool,
    mut capture: impl FnMut(bool, u32) -> Result<bool, String>,
    cancel: impl FnOnce() -> Result<(), String>,
) -> Result<(), String> {
    check_cancelled(cancelled)?;
    let deadline = Instant::now() + Duration::from_secs(180);
    let result = (|| {
        let mut first = true;
        loop {
            check_cancelled(cancelled)?;
            if Instant::now() >= deadline {
                return Err("指纹录入超时，请重试".into());
            }
            let remaining = capture(first, CAPTURE_WAIT_MS)?;
            if !remaining {
                return Ok(());
            }
            check_cancelled(cancelled)?;
            first = false;
        }
    })();
    finish(result, cancelled, cancel)
}

pub(super) fn finish(
    result: Result<(), String>,
    cancelled: &dyn Fn() -> bool,
    cancel: impl FnOnce() -> Result<(), String>,
) -> Result<(), String> {
    if let Err(error) = result {
        // 在采样调用返回后由同一线程取消，避免并发使用设备句柄。
        return match cancel() {
            Ok(()) if cancelled() => Err("指纹录入已取消".into()),
            Ok(()) => Err(error),
            Err(cleanup) => Err(format!(
                "{error}；取消录入失败：{cleanup}，请重新插拔认证器"
            )),
        };
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;

    #[test]
    fn idle_capture_rounds_keep_session_and_cancel_without_counting_samples() {
        let closing = Cell::new(false);
        let mut rounds = 0;
        let mut samples = 0;
        let mut cleanups = 0;
        let error = run(
            &|| closing.get(),
            |first, wait_ms| {
                assert_eq!(first, rounds == 0);
                assert_eq!(wait_ms, 1_000);
                rounds += 1;
                if rounds == 3 {
                    closing.set(true);
                }
                sample_result(0x0d, 0, &mut || samples += 1)
            },
            || {
                cleanups += 1;
                Ok(())
            },
        )
        .unwrap_err();
        assert_eq!(error, "指纹录入已取消");
        assert_eq!((rounds, samples, cleanups), (3, 0, 1));
    }

    #[test]
    fn only_good_samples_advance_and_finish_enrollment() {
        let mut samples = 0;
        for (status, remaining, pending) in [
            (0x0d, 3, true),
            (0, 2, true),
            (0x0e, 2, true),
            (0, 0, false),
        ] {
            assert_eq!(
                sample_result(status, remaining, &mut || samples += 1).unwrap(),
                pending
            );
        }
        assert_eq!(samples, 2);
        assert!(sample_result(0xff, 0, &mut || samples += 1).is_err());
        assert_eq!(samples, 2);
    }

    #[test]
    fn shutdown_during_capture_cancels_before_another_sample() {
        let closing = Cell::new(false);
        let cleaned = Cell::new(false);
        let mut captures = 0;
        let result = run(
            &|| closing.get(),
            |_, _| {
                captures += 1;
                closing.set(true);
                Ok(true)
            },
            || {
                cleaned.set(true);
                Ok(())
            },
        );
        assert!(result.unwrap_err().contains("已取消"));
        assert_eq!(captures, 1);
        assert!(cleaned.get());
    }

    #[test]
    fn already_closing_does_not_start_enrollment() {
        assert!(run(
            &|| true,
            |_, _| panic!("不应开始采样"),
            || panic!("尚未开始录入")
        )
        .is_err());
    }

    #[test]
    fn capture_failure_runs_cleanup_and_reports_cleanup_failure() {
        let error = run(
            &|| false,
            |_, _| Err("采样超时".into()),
            || Err("设备未响应".into()),
        )
        .unwrap_err();
        assert!(error.contains("采样超时"));
        assert!(error.contains("取消录入失败"));
    }

    #[test]
    fn completed_enrollment_is_not_cancelled() {
        let mut calls = 0;
        run(
            &|| false,
            |first, _| {
                assert_eq!(first, calls == 0);
                calls += 1;
                Ok(calls < 3)
            },
            || panic!("成功录入不应取消"),
        )
        .unwrap();
        assert_eq!(calls, 3);
    }
}

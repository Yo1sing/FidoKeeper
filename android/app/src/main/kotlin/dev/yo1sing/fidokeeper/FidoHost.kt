package dev.yo1sing.fidokeeper

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Build
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class FidoHost(private val activity: MainActivity) {
    companion object {
        init {
            System.loadLibrary("rust_lib_fidokeeper")
        }

        private const val USB_PERMISSION = "dev.yo1sing.fidokeeper.USB_PERMISSION"
        private val FIDO_AID =
            byteArrayOf(0xA0.toByte(), 0x00, 0x00, 0x06, 0x47, 0x2F, 0x00, 0x01)

        @JvmStatic
        external fun nativeRegister(host: FidoHost)

        fun bind(activity: MainActivity): FidoHost {
            val host = FidoHost(activity)
            nativeRegister(host)
            return host
        }
    }

    private val usbManager = activity.getSystemService(Context.USB_SERVICE) as UsbManager
    private val sessions = ConcurrentHashMap<Int, Session>()
    private val nextId = AtomicInteger(1)
    private val permissionLock = Object()
    @Volatile private var permissionGranted = false
    @Volatile var nfcTag: Tag? = null

    private val permissionReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != USB_PERMISSION) {
                    return
                }
                synchronized(permissionLock) {
                    permissionGranted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    permissionLock.notifyAll()
                }
            }
        }

    init {
        val filter = IntentFilter(USB_PERMISSION)
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(permissionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(permissionReceiver, filter)
        }
    }

    fun filesDir(): String = activity.filesDir.absolutePath

    fun list(): Array<String> {
        val devices = mutableListOf<String>()
        for (device in usbManager.deviceList.values) {
            if (hasCandidateHid(device)) {
                val label = "${device.manufacturerName ?: ""} ${device.productName ?: ""}".trim()
                devices.add("usb:${device.deviceName}\t${label.ifEmpty { "FIDO 认证器" }}")
            }
        }
        nfcTag?.let { tag ->
            val id = tag.id?.joinToString("") { byte -> "%02x".format(byte) } ?: "nfc"
            devices.add("nfc:$id\tNFC 安全密钥")
        }
        return devices.toTypedArray()
    }

    fun open(path: String): Int {
        return if (path.startsWith("nfc")) {
            openNfc()
        } else {
            openUsb(path.removePrefix("usb:"))
        }
    }

    fun packetSize(handle: Int): Int = session(handle).packetSize

    fun hidWrite(handle: Int, packet: ByteArray) {
        val session = session(handle) as? UsbSession ?: throw IOException("当前不是 USB 会话")
        val sent = session.connection.bulkTransfer(session.epOut, packet, packet.size, 3_000)
        if (sent != packet.size) {
            throw IOException("USB 写入失败")
        }
    }

    fun hidRead(handle: Int, timeoutMs: Int): ByteArray {
        val session = session(handle) as? UsbSession ?: throw IOException("当前不是 USB 会话")
        val packet = ByteArray(session.packetSize)
        val read =
            session.connection.bulkTransfer(session.epIn, packet, packet.size, timeoutMs.coerceAtLeast(1))
        if (read <= 0) {
            throw IOException("USB 读取超时")
        }
        return packet
    }

    fun nfcTransmit(handle: Int, apdu: ByteArray, timeoutMs: Int): ByteArray {
        val session = session(handle) as? NfcSession ?: throw IOException("当前不是 NFC 会话")
        session.iso.timeout = timeoutMs.coerceAtLeast(1)
        return complete(session.iso.transceive(apdu), session.iso)
    }

    fun close(handle: Int) {
        sessions.remove(handle)?.close()
    }

    fun onNfcTag(tag: Tag?) {
        nfcTag = tag
    }

    fun enableNfc() {
        val adapter = NfcAdapter.getDefaultAdapter(activity) ?: return
        adapter.enableReaderMode(
            activity,
            { tag -> nfcTag = tag },
            NfcAdapter.FLAG_READER_NFC_A or
                NfcAdapter.FLAG_READER_NFC_B or
                NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
            null,
        )
    }

    fun disableNfc() {
        NfcAdapter.getDefaultAdapter(activity)?.disableReaderMode(activity)
    }

    fun release() {
        disableNfc()
        runCatching { activity.unregisterReceiver(permissionReceiver) }
        sessions.values.forEach { it.close() }
        sessions.clear()
    }

    private fun openUsb(deviceName: String): Int {
        val device =
            usbManager.deviceList.values.find { it.deviceName == deviceName }
                ?: throw IOException("USB 设备已断开")
        ensurePermission(device)
        val connection = usbManager.openDevice(device) ?: throw IOException("无法打开 USB 设备")
        val claimed = findFidoInterface(device, connection)
        if (claimed == null) {
            connection.close()
            throw IOException("未找到 FIDO HID 接口")
        }
        val (intf, epIn, epOut) = claimed
        val id = nextId.getAndIncrement()
        sessions[id] = UsbSession(connection, intf, epIn, epOut, maxOf(epIn.maxPacketSize, epOut.maxPacketSize, 64))
        return id
    }

    private fun openNfc(): Int {
        val tag = nfcTag ?: throw IOException("请将安全密钥贴在 NFC 感应区")
        val iso = IsoDep.get(tag) ?: throw IOException("此标签不是 ISO-DEP")
        iso.timeout = 30_000
        iso.connect()
        val select = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, 0x08) + FIDO_AID + byteArrayOf(0x00)
        try {
            complete(iso.transceive(select), iso)
        } catch (error: Exception) {
            iso.close()
            throw IOException("无法选择 FIDO 应用", error)
        }
        val id = nextId.getAndIncrement()
        sessions[id] = NfcSession(iso)
        return id
    }

    private fun ensurePermission(device: UsbDevice) {
        if (usbManager.hasPermission(device)) {
            return
        }
        val flags =
            if (Build.VERSION.SDK_INT >= 31) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        val intent =
            PendingIntent.getBroadcast(activity, 0, Intent(USB_PERMISSION).setPackage(activity.packageName), flags)
        synchronized(permissionLock) {
            permissionGranted = false
            usbManager.requestPermission(device, intent)
            permissionLock.wait(60_000)
        }
        if (!usbManager.hasPermission(device)) {
            throw IOException("未授予 USB 权限")
        }
    }

    private fun hasCandidateHid(device: UsbDevice): Boolean {
        for (index in 0 until device.interfaceCount) {
            val intf = device.getInterface(index)
            if (isHidCandidate(intf)) {
                return true
            }
        }
        return false
    }

    private fun isHidCandidate(intf: UsbInterface): Boolean {
        return intf.interfaceClass == UsbConstants.USB_CLASS_HID &&
            intf.interfaceSubclass == 0 &&
            intf.interfaceProtocol == 0
    }

    private fun findFidoInterface(
        device: UsbDevice,
        connection: UsbDeviceConnection,
    ): Triple<UsbInterface, UsbEndpoint, UsbEndpoint>? {
        for (index in 0 until device.interfaceCount) {
            val intf = device.getInterface(index)
            if (!isHidCandidate(intf)) {
                continue
            }
            if (!connection.claimInterface(intf, true)) {
                continue
            }
            if (!looksLikeFido(connection, intf)) {
                connection.releaseInterface(intf)
                continue
            }
            var epIn: UsbEndpoint? = null
            var epOut: UsbEndpoint? = null
            for (e in 0 until intf.endpointCount) {
                val endpoint = intf.getEndpoint(e)
                if (endpoint.direction == UsbConstants.USB_DIR_IN) {
                    epIn = endpoint
                } else {
                    epOut = endpoint
                }
            }
            if (epIn != null && epOut != null) {
                return Triple(intf, epIn, epOut)
            }
            connection.releaseInterface(intf)
        }
        return null
    }

    private fun looksLikeFido(connection: UsbDeviceConnection, intf: UsbInterface): Boolean {
        val buffer = ByteArray(4096)
        val length = connection.controlTransfer(0x81, 0x06, 0x2200, intf.id, buffer, buffer.size, 2_000)
        if (length <= 0) {
            // 描述符读不到时交给后续 CTAPHID INIT 判定。
            return true
        }
        for (i in 0 until length - 2) {
            if (buffer[i] == 0x06.toByte() && buffer[i + 1] == 0xD0.toByte() && buffer[i + 2] == 0xF1.toByte()) {
                return true
            }
        }
        return false
    }

    private fun complete(response: ByteArray, iso: IsoDep): ByteArray {
        var data = response
        val payload = ArrayList<Byte>()
        while (true) {
            if (data.size < 2) {
                throw IOException("NFC 应答过短")
            }
            payload.addAll(data.copyOf(data.size - 2).toList())
            val sw1 = data[data.size - 2].toInt() and 0xFF
            val sw2 = data[data.size - 1].toInt() and 0xFF
            if (sw1 == 0x61) {
                data = iso.transceive(byteArrayOf(0x00, 0xC0.toByte(), 0x00, 0x00, sw2.toByte()))
                continue
            }
            if (sw1 != 0x90 || sw2 != 0x00) {
                throw IOException("NFC 状态字 ${sw1.toString(16)} ${sw2.toString(16)}")
            }
            return payload.toByteArray()
        }
    }

    private fun session(handle: Int): Session {
        return sessions[handle] ?: throw IOException("会话已关闭")
    }

    private sealed class Session {
        abstract val packetSize: Int

        abstract fun close()
    }

    private class UsbSession(
        val connection: UsbDeviceConnection,
        val intf: UsbInterface,
        val epIn: UsbEndpoint,
        val epOut: UsbEndpoint,
        override val packetSize: Int,
    ) : Session() {
        override fun close() {
            connection.releaseInterface(intf)
            connection.close()
        }
    }

    private class NfcSession(val iso: IsoDep) : Session() {
        override val packetSize: Int = 0

        override fun close() {
            runCatching { iso.close() }
        }
    }
}

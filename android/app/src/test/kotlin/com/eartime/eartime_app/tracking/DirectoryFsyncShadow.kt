package com.eartime.eartime_app.tracking

import android.system.ErrnoException
import android.system.OsConstants
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowLinux
import java.io.File
import java.io.FileDescriptor
import java.io.FileInputStream
import java.util.IdentityHashMap

/** Windows ShadowLinux cannot open directories. Models ONLY that syscall boundary, not durability. */
@Implements(className = "libcore.io.Linux", isInAndroidSdk = false)
class DirectoryFsyncShadow : ShadowLinux() {
    companion object {
        val synced = mutableListOf<String>()
        var failSync = false
        private val directories = IdentityHashMap<FileDescriptor, String>()
        fun resetFixture() { synced.clear(); directories.clear(); failSync = false }
    }
    @Implementation
    override fun open(path: String, flags: Int, mode: Int): FileDescriptor {
        if (!File(path).isDirectory) return super.open(path, flags, mode)
        check(flags == OsConstants.O_RDONLY)
        return FileDescriptor().also { directories[it] = path }
    }
    @Implementation
    protected fun fsync(descriptor: FileDescriptor) {
        val directory = directories[descriptor]
        if (directory == null) descriptor.sync() else {
            if (failSync) throw ErrnoException("fsync", OsConstants.EIO)
            synced.add(directory)
        }
    }
    @Implementation
    protected fun close(descriptor: FileDescriptor) {
        if (directories.remove(descriptor) == null) FileInputStream(descriptor).close()
    }
}

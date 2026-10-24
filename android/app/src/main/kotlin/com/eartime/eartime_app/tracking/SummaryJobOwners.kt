package com.eartime.eartime_app.tracking

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

internal class SummaryJobOwners {
    class Owner(val id: Int, val token: String) { val active = AtomicBoolean(true) }
    private val current = ConcurrentHashMap<Int, Owner>()
    @Synchronized fun start(id: Int, token: String): Owner {
        current[id]?.let { if (it.token == token && it.active.get()) return it }
        return Owner(id, token).also { current.put(id, it)?.active?.set(false) }
    }
    fun active(owner: Owner) = owner.active.get() && current[owner.id] === owner
    fun finish(owner: Owner): Boolean { owner.active.set(false); return current.remove(owner.id, owner) }
    fun stop(id: Int, token: String) { current[id]?.let { if (it.token == token) finish(it) } }
}

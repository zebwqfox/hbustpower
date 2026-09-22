package com.zebwqfox.hbustpower.data

import android.content.SharedPreferences

/**
 * An in-memory [SharedPreferences] for JVM tests. Android's own implementation is a stub outside an emulator,
 * and the repository only needs get/put plus `edit {}`, so a map is enough.
 */
class FakePreferences : SharedPreferences {
    private val values = mutableMapOf<String, Any?>()

    override fun getAll(): MutableMap<String, *> = values.toMutableMap()
    override fun getString(key: String?, defValue: String?): String? = values[key] as? String ?: defValue
    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        (values[key] as? Set<String>)?.toMutableSet() ?: defValues
    override fun getInt(key: String?, defValue: Int): Int = values[key] as? Int ?: defValue
    override fun getLong(key: String?, defValue: Long): Long = values[key] as? Long ?: defValue
    override fun getFloat(key: String?, defValue: Float): Float = values[key] as? Float ?: defValue
    override fun getBoolean(key: String?, defValue: Boolean): Boolean = values[key] as? Boolean ?: defValue
    override fun contains(key: String?): Boolean = values.containsKey(key)
    override fun edit(): SharedPreferences.Editor = Editor()
    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) = Unit
    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) = Unit

    /** Writes land only on commit/apply, as they do on a device. */
    private inner class Editor : SharedPreferences.Editor {
        private val pending = mutableMapOf<String, Any?>()
        private val removed = mutableSetOf<String>()
        private var clearAll = false

        // Named `store` rather than using `apply`, which is also the name of an override on this interface.
        private fun store(key: String?, value: Any?): SharedPreferences.Editor {
            pending[key.orEmpty()] = value
            removed -= key.orEmpty()
            return this
        }

        override fun putString(key: String?, value: String?): SharedPreferences.Editor = store(key, value)
        override fun putStringSet(key: String?, values: MutableSet<String>?): SharedPreferences.Editor = store(key, values?.toSet())
        override fun putInt(key: String?, value: Int): SharedPreferences.Editor = store(key, value)
        override fun putLong(key: String?, value: Long): SharedPreferences.Editor = store(key, value)
        override fun putFloat(key: String?, value: Float): SharedPreferences.Editor = store(key, value)
        override fun putBoolean(key: String?, value: Boolean): SharedPreferences.Editor = store(key, value)

        override fun remove(key: String?): SharedPreferences.Editor {
            removed += key.orEmpty()
            pending -= key.orEmpty()
            return this
        }

        override fun clear(): SharedPreferences.Editor {
            clearAll = true
            return this
        }

        override fun commit(): Boolean {
            if (clearAll) values.clear()
            removed.forEach { values -= it }
            values.putAll(pending)
            return true
        }

        override fun apply() {
            commit()
        }
    }
}

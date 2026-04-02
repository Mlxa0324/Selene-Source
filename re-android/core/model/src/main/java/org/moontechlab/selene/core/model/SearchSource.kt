package org.moontechlab.selene.core.model

data class SearchSource(
    val key: String,
    val name: String,
    val api: String,
    val detail: String = "",
    val disabled: Boolean = false,
)

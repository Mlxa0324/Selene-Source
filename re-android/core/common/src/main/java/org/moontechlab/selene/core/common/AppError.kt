package org.moontechlab.selene.core.common

sealed interface AppError {
    data object AuthExpired : AppError

    data class Network(
        val message: String,
    ) : AppError

    data class Unknown(
        val message: String,
    ) : AppError
}

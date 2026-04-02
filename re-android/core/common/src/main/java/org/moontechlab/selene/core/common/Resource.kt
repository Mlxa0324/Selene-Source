package org.moontechlab.selene.core.common

sealed class Resource<T>(
    open val data: T? = null,
) {
    data class Loading<T>(
        override val data: T? = null,
    ) : Resource<T>(data)

    data class Success<T>(
        override val data: T,
    ) : Resource<T>(data)

    data class Error<T>(
        val error: AppError,
        override val data: T? = null,
    ) : Resource<T>(data)
}

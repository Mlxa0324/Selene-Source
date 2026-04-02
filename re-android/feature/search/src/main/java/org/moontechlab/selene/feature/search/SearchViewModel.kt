package org.moontechlab.selene.feature.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.moontechlab.selene.core.common.CoroutineDispatchers
import org.moontechlab.selene.core.common.DefaultCoroutineDispatchers
import org.moontechlab.selene.core.model.VideoCardModel

data class SearchUiState(
    val query: String = "",
    val isLoading: Boolean = false,
    val results: List<VideoCardModel> = emptyList(),
)

class SearchViewModel(
    private val repository: SearchRepository = SearchRepository(),
    private val dispatchers: CoroutineDispatchers = DefaultCoroutineDispatchers,
) : ViewModel() {
    private val mutableUiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = mutableUiState.asStateFlow()

    fun updateQuery(value: String) {
        mutableUiState.value = mutableUiState.value.copy(query = value)
    }

    fun search() {
        val keyword = mutableUiState.value.query.trim()
        if (keyword.isEmpty()) return

        mutableUiState.value = mutableUiState.value.copy(isLoading = true)
        viewModelScope.launch(dispatchers.io) {
            val results = repository.search(keyword)
            mutableUiState.value = mutableUiState.value.copy(
                isLoading = false,
                results = results,
            )
        }
    }
}

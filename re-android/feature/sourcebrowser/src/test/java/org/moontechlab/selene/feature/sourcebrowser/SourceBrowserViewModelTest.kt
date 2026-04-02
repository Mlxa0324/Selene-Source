package org.moontechlab.selene.feature.sourcebrowser

import org.junit.Assert.assertEquals
import org.junit.Test

class SourceBrowserViewModelTest {

    @Test
    fun `switching source updates visible catalog entries`() {
        val viewModel = SourceBrowserViewModel()

        assertEquals(listOf("热门推荐", "动漫专栏", "纪录片"), viewModel.uiState.value.sources.map { it.name })
        assertEquals("热门推荐", viewModel.uiState.value.selectedSourceName)
        assertEquals("流浪地球 2", viewModel.uiState.value.entries.first().title)

        viewModel.selectSource("anime")

        assertEquals("动漫专栏", viewModel.uiState.value.selectedSourceName)
        assertEquals(listOf("凡人修仙传", "灵笼"), viewModel.uiState.value.entries.map { it.title })
    }
}

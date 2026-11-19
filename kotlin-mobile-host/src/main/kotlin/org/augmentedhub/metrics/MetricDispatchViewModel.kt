package org.augmentedhub.metrics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed interface MetricDispatchUiState {
    data object Idle : MetricDispatchUiState
    data object Loading : MetricDispatchUiState
    data class Success(
        val response: MetricResponse,
        val source: ResponseSource,
    ) : MetricDispatchUiState
    data class Error(
        val errorCode: String,
        val message: String,
        val metric: String?,
    ) : MetricDispatchUiState
}

enum class ResponseSource {
    Network,
    LastKnownAggregateCache,
}

class MetricDispatchViewModel(
    private val repository: MetricDispatchRepository,
) : ViewModel() {
    private val mutableState = MutableStateFlow<MetricDispatchUiState>(
        MetricDispatchUiState.Idle,
    )

    val state: StateFlow<MetricDispatchUiState> = mutableState.asStateFlow()

    suspend fun dispatch(request: MetricRequest): MetricResponse {
        mutableState.value = MetricDispatchUiState.Loading

        return when (val result = repository.dispatch(request)) {
            is MetricDispatchResult.Success -> {
                mutableState.value = MetricDispatchUiState.Success(
                    response = result.response,
                    source = ResponseSource.Network,
                )
                result.response
            }

            is MetricDispatchResult.Failure -> {
                val lastKnown = repository.lastKnown(request.metric)

                if (lastKnown != null) {
                    mutableState.value = MetricDispatchUiState.Success(
                        response = lastKnown,
                        source = ResponseSource.LastKnownAggregateCache,
                    )
                    return lastKnown
                }

                mutableState.value = MetricDispatchUiState.Error(
                    errorCode = result.errorCode,
                    message = result.message,
                    metric = result.metric,
                )

                throw MetricDispatchException(
                    errorCode = result.errorCode,
                    message = result.message,
                )
            }
        }
    }

    fun dispatchFromUi(request: MetricRequest) {
        viewModelScope.launch {
            runCatching {
                dispatch(request)
            }
        }
    }

    fun clearLastKnownMetrics() {
        viewModelScope.launch {
            repository.clearAll()
            mutableState.value = MetricDispatchUiState.Idle
        }
    }
}

class MetricDispatchException(
    val errorCode: String,
    override val message: String,
) : IllegalStateException(message)

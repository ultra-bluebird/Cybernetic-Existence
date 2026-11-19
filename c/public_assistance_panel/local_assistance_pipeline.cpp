#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace augmented_hub::public_assistance {

struct AudioFrame {
    std::vector<std::int16_t> samples;
    std::uint32_t sample_rate_hz;
};

struct LocalTranscript {
    std::string text;
    float confidence;
};

struct LocalResponse {
    std::string plain_language_text;
    bool should_render_captions;
    bool should_use_speech;
    bool should_use_tactile_confirmation;
};

class VoiceActivityDetector {
public:
    [[nodiscard]] bool containsSpeech(const AudioFrame& frame) const {
        if (frame.sample_rate_hz == 0 || frame.samples.empty()) {
            return false;
        }

        std::int64_t energy = 0;
        for (const auto sample : frame.samples) {
            energy += static_cast<std::int64_t>(sample) * sample;
        }

        const auto meanEnergy = energy /
            static_cast<std::int64_t>(frame.samples.size());

        return meanEnergy >= minimumSpeechEnergy_;
    }

private:
    static constexpr std::int64_t minimumSpeechEnergy_ = 4500;
};

class OnDeviceSpeechRecognizer {
public:
    [[nodiscard]] std::optional<LocalTranscript> transcribe(
        const AudioFrame& frame
    ) const {
        if (frame.sample_rate_hz != requiredSampleRateHz_) {
            return std::nullopt;
        }

        if (frame.samples.empty()) {
            return std::nullopt;
        }

        return LocalTranscript{
            .text = "Local transcription requires an installed offline speech model.",
            .confidence = 0.0F,
        };
    }

private:
    static constexpr std::uint32_t requiredSampleRateHz_ = 16000;
};

class LocalLanguageModel {
public:
    [[nodiscard]] LocalResponse answer(
        std::string_view localTranscript,
        bool captionsEnabled,
        bool speechEnabled,
        bool tactileConfirmationEnabled
    ) const {
        const bool asksForPrivacy =
            localTranscript.find("privacy") != std::string_view::npos;

        if (asksForPrivacy) {
            return LocalResponse{
                .plain_language_text =
                    "This panel processes speech locally. It does not send audio, "
                    "transcripts, or saved accessibility preferences to cloud services.",
                .should_render_captions = captionsEnabled,
                .should_use_speech = speechEnabled,
                .should_use_tactile_confirmation = tactileConfirmationEnabled,
            };
        }

        return LocalResponse{
            .plain_language_text =
                "This panel can provide local municipal information using speech, "
                "keyboard, tactile controls, captions, or screen-reader-compatible text.",
            .should_render_captions = captionsEnabled,
            .should_use_speech = speechEnabled,
            .should_use_tactile_confirmation = tactileConfirmationEnabled,
        };
    }
};

class LocalAssistancePipeline {
public:
    [[nodiscard]] std::optional<LocalResponse> process(
        const AudioFrame& frame,
        bool microphoneHardwareEnabled,
        bool captionsEnabled,
        bool speechEnabled,
        bool tactileConfirmationEnabled
    ) const {
        if (!microphoneHardwareEnabled) {
            return std::nullopt;
        }

        if (!voiceActivityDetector_.containsSpeech(frame)) {
            return std::nullopt;
        }

        const auto transcript = recognizer_.transcribe(frame);
        if (!transcript.has_value() || transcript->confidence < minimumConfidence_) {
            return LocalResponse{
                .plain_language_text =
                    "I could not confidently understand that. You can try again, "
                    "use the keyboard, or select an option on the screen.",
                .should_render_captions = true,
                .should_use_speech = speechEnabled,
                .should_use_tactile_confirmation = tactileConfirmationEnabled,
            };
        }

        return languageModel_.answer(
            transcript->text,
            captionsEnabled,
            speechEnabled,
            tactileConfirmationEnabled
        );
    }

private:
    VoiceActivityDetector voiceActivityDetector_;
    OnDeviceSpeechRecognizer recognizer_;
    LocalLanguageModel languageModel_;
    static constexpr float minimumConfidence_ = 0.72F;
};

}  // namespace augmented_hub::public_assistance

"""LiteLLM proxy: GLM-4.7-Flash params + Ollama Qwen3/DeepSeek thinking → content."""
from __future__ import annotations

import re
from typing import Any, Literal, Optional

import litellm
from litellm.integrations.custom_logger import CustomLogger
from litellm.proxy.proxy_server import DualCache, UserAPIKeyAuth

from .agl_ollama_thinking_utils import (
    is_ollama_route,
    normalize_ollama_message_content,
    ollama_uses_thinking,
)

MIN_MAX_TOKENS = 512

_GLM_FLASH_PATTERN = re.compile(
    r"(^|/)(glm-4\.7-flash|glm-flash|zai-glm-flash|zai/glm-4\.7-flash|openai/glm-4\.7-flash|agl-primary-zai-glm-flash)$",
    re.I,
)


def _is_glm_flash_route(model: Optional[str]) -> bool:
    if not model:
        return False
    return bool(_GLM_FLASH_PATTERN.search(model.strip()))


class AglGlmFlashParamsHandler(CustomLogger):
    async def async_pre_call_hook(
        self,
        user_api_key_dict: UserAPIKeyAuth,
        cache: DualCache,
        data: dict,
        call_type: Literal[
            "completion",
            "text_completion",
            "embeddings",
            "image_generation",
            "moderation",
            "audio_transcription",
        ],
    ) -> dict:
        if call_type not in ("completion", "text_completion"):
            return data

        model = data.get("model") or data.get("litellm_model_name") or ""
        model_str = str(model)

        if _is_glm_flash_route(model_str):
            current = data.get("max_tokens")
            if current is None or (isinstance(current, int) and current < MIN_MAX_TOKENS):
                data["max_tokens"] = MIN_MAX_TOKENS

            deployment = str(
                data.get("litellm_metadata", {}).get("deployment", ""))
            api_base = str(data.get("api_base") or "")
            model_slug = model_str.lower()
            use_paas_thinking_off = (
                "paas/v4" in api_base
                or model_slug.startswith("zai/")
                or "glm-4.7-flash" in deployment
            )
            if use_paas_thinking_off and not model_slug.startswith("openai/"):
                extra = dict(data.get("extra_body") or {})
                thinking = extra.get("thinking")
                if not isinstance(thinking, dict):
                    thinking = {}
                if thinking.get("type") != "enabled":
                    extra["thinking"] = {"type": "disabled"}
                data["extra_body"] = extra

        if is_ollama_route(model_str, data) and ollama_uses_thinking(model_str, data):
            if data.get("think") is not False:
                data["think"] = False
            extra = dict(data.get("extra_body") or {})
            if extra.get("think") is not False:
                extra["think"] = False
            data["extra_body"] = extra
            if data.get("reasoning_effort"):
                data.pop("reasoning_effort", None)

        return data

    async def async_post_call_success_hook(
        self,
        data: dict,
        user_api_key_dict: UserAPIKeyAuth,
        response: Any,
    ) -> Any:
        model = data.get("model") or data.get("litellm_model_name") or ""
        if not is_ollama_route(str(model), data):
            return response

        if isinstance(response, litellm.ModelResponse):
            for choice in response.choices or []:
                normalize_ollama_message_content(
                    getattr(choice, "message", None))
            return response

        return response


proxy_handler_instance = AglGlmFlashParamsHandler()

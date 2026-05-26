"""LiteLLM proxy: GLM-4.7-Flash — max_tokens mínimo e thinking desactivado (evita content vazio)."""
from __future__ import annotations

import re
from typing import Literal, Optional

from litellm.integrations.custom_logger import CustomLogger
from litellm.proxy.proxy_server import DualCache, UserAPIKeyAuth

MIN_MAX_TOKENS = 512

# Aliases / slugs que usam GLM-4.7-Flash ou variantes com reasoning_content na Z.AI
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
        if not _is_glm_flash_route(str(model)):
            return data

        current = data.get("max_tokens")
        if current is None or (isinstance(current, int) and current < MIN_MAX_TOKENS):
            data["max_tokens"] = MIN_MAX_TOKENS

        # thinking.type=disabled na Z.AI PaaS v4 (zai/*); OpenAI-compat openai/glm-4.7-flash não aceita extra_body.thinking (404)
        deployment = str(
            data.get("litellm_metadata", {}).get("deployment", ""))
        api_base = str(data.get("api_base") or "")
        model_slug = str(model).lower()
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

        return data


proxy_handler_instance = AglGlmFlashParamsHandler()

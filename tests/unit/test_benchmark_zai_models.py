"""Testes da lógica não-trivial do benchmark Z.AI: classificação de backend e ranking.

A deteção de fallback (alias Z.AI servido por outro provider) é o coração do
benchmark — se falhar, o relatório recomenda o modelo errado.
"""
import importlib.util
import sys
from pathlib import Path

_SCRIPT = Path(__file__).resolve(
).parents[2] / "scripts" / "litellm" / "benchmark-zai-models.py"
_spec = importlib.util.spec_from_file_location("benchmark_zai_models", _SCRIPT)
bz = importlib.util.module_from_spec(_spec)
# necessário para @dataclass resolver cls.__module__
sys.modules[_spec.name] = bz
_spec.loader.exec_module(bz)


class TestClassifyBackend:
    def test_provider_zai_explicit(self):
        assert bz.classify_backend("glm-4.5-flash", "Z.AI") == "zai"
        assert bz.classify_backend("anything", "zhipu") == "zai"

    def test_fallback_nemotron_via_nvidia(self):
        # caso real observado: zai-coding-glm-4.7 → Nemotron (Nvidia)
        assert bz.classify_backend(
            "nvidia/nemotron-3-ultra-550b-a55b-20260604:free", "Nvidia"
        ) == "fallback"

    def test_fallback_groq_openrouter(self):
        assert bz.classify_backend("llama-3.1-8b", "Groq") == "fallback"
        assert bz.classify_backend(
            "z-ai/glm-4.5-air:free", "OpenRouter") == "fallback"

    def test_model_name_heuristic_when_no_provider(self):
        assert bz.classify_backend("glm-5", "") == "zai"
        assert bz.classify_backend("nemotron-super", "") == "fallback"
        assert bz.classify_backend("gpt-5-nano", "") == "fallback"

    def test_unknown(self):
        assert bz.classify_backend("", "") == "unknown"

    def test_openrouter_glm_air_is_fallback_not_zai(self):
        # nome tem "glm" mas provider OpenRouter manda → fallback (não Z.AI directo)
        assert bz.classify_backend(
            "z-ai/glm-4.5-air:free", "OpenRouter") == "fallback"


class TestJsonToolCheck:
    def test_plain_json(self):
        assert bz._json_tool_check('{"tool":"read_file","args":{"path":"x"}}')

    def test_markdown_fenced_json(self):
        assert bz._json_tool_check(
            '```json\n{"tool":"read_file","args":{}}\n```')

    def test_wrong_tool(self):
        assert not bz._json_tool_check('{"tool":"write_file","args":{}}')

    def test_garbage(self):
        assert not bz._json_tool_check("não é json")


class TestRank:
    def _rep(self, alias, ok, zai, q_ok, q_total, lat):
        r = bz.ModelReport(alias=alias)
        r.ok_runs = ok
        r.zai_runs = zai
        r.fallback_runs = ok - zai
        r.quality_ok = q_ok
        r.quality_total = q_total
        r.median_latency_ms = lat
        return r

    def test_fidelity_beats_latency(self):
        # modelo Z.AI mais lento deve ranquear acima de fallback rápido
        zai_slow = self._rep("zai-glm-5", ok=4, zai=4,
                             q_ok=4, q_total=4, lat=900)
        fb_fast = self._rep("glm-4.7-flash", ok=4, zai=0,
                            q_ok=4, q_total=4, lat=200)
        ranked = bz.rank([fb_fast, zai_slow])
        assert ranked[0].alias == "zai-glm-5"

    def test_quality_breaks_fidelity_tie(self):
        a = self._rep("a", ok=4, zai=4, q_ok=4, q_total=4, lat=500)
        b = self._rep("b", ok=4, zai=4, q_ok=2, q_total=4, lat=300)
        ranked = bz.rank([b, a])
        assert ranked[0].alias == "a"

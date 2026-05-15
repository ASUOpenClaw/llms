DC      := docker compose --project-name llms
ARGS    ?=

ALL_FILES := \
	-f docker-compose.vllm.yml \
	-f docker-compose.ollama.yml \
	-f docker-compose.lmdeploy.yml \
	-f docker-compose.embeddings.yml \
	-f docker-compose.speaches.yml \
	-f docker-compose.docling.yml \
	-f docker-compose.litellm.yml

.PHONY: network \
        vllm ollama lmdeploy \
        embeddings speaches docling \
        all-vllm all-ollama all-lmdeploy \
        down ps logs pull

# ── Prerequisite ───────────────────────────────────────────────────────────
network:
	docker network create openclaw-net 2>/dev/null || true

# ── Single components ──────────────────────────────────────────────────────
embeddings: network
	$(DC) -f docker-compose.embeddings.yml up -d $(ARGS)

speaches: network
	$(DC) -f docker-compose.speaches.yml up -d $(ARGS)

docling: network
	$(DC) -f docker-compose.docling.yml up -d $(ARGS)

# ── LLM provider + LiteLLM (choose one) ───────────────────────────────────
#   Exposed:  litellm :4000
#   Internal: vllm/ollama/lmdeploy on openclaw-net only

vllm: network
	LITELLM_CONFIG=./litellm_config.vllm.yaml \
	$(DC) -f docker-compose.vllm.yml \
	      -f docker-compose.litellm.yml up -d $(ARGS)

ollama: network
	LITELLM_CONFIG=./litellm_config.ollama.yaml \
	$(DC) -f docker-compose.ollama.yml \
	      -f docker-compose.litellm.yml up -d $(ARGS)

lmdeploy: network
	LITELLM_CONFIG=./litellm_config.lmdeploy.yaml \
	$(DC) -f docker-compose.lmdeploy.yml \
	      -f docker-compose.litellm.yml up -d $(ARGS)

# ── Full stack: LLM + embeddings + speaches + docling + litellm ───────────
all-vllm: network
	LITELLM_CONFIG=./litellm_config.vllm.yaml \
	$(DC) -f docker-compose.vllm.yml \
	      -f docker-compose.embeddings.yml \
	      -f docker-compose.speaches.yml \
	      -f docker-compose.docling.yml \
	      -f docker-compose.litellm.yml up -d $(ARGS)

all-ollama: network
	LITELLM_CONFIG=./litellm_config.ollama.yaml \
	$(DC) -f docker-compose.ollama.yml \
	      -f docker-compose.embeddings.yml \
	      -f docker-compose.speaches.yml \
	      -f docker-compose.docling.yml \
	      -f docker-compose.litellm.yml up -d $(ARGS)

all-lmdeploy: network
	LITELLM_CONFIG=./litellm_config.lmdeploy.yaml \
	$(DC) -f docker-compose.lmdeploy.yml \
	      -f docker-compose.embeddings.yml \
	      -f docker-compose.speaches.yml \
	      -f docker-compose.docling.yml \
	      -f docker-compose.litellm.yml up -d $(ARGS)

# ── Management ─────────────────────────────────────────────────────────────
down:
	$(DC) $(ALL_FILES) down $(ARGS)

ps:
	$(DC) $(ALL_FILES) ps

logs:
	$(DC) $(ALL_FILES) logs -f $(ARGS)

help:
	@echo "LLM provider + LiteLLM:"
	@echo "  make vllm        — vLLM (Qwen3-8B-AWQ) + LiteLLM"
	@echo "  make ollama      — Ollama (Qwen3 128k) + LiteLLM"
	@echo "  make lmdeploy    — LMDeploy (Qwen3-14B-AWQ) + LiteLLM"
	@echo ""
	@echo "Full stack (LLM + embeddings + speaches + docling + litellm):"
	@echo "  make all-vllm"
	@echo "  make all-ollama"
	@echo "  make all-lmdeploy"
	@echo ""
	@echo "Individual components:"
	@echo "  make embeddings  — embedding server only"
	@echo "  make speaches    — Speaches STT/TTS only"
	@echo "  make docling     — Docling document parser only"
	@echo ""
	@echo "Management:"
	@echo "  make down        — stop all services"
	@echo "  make ps          — show running services"
	@echo "  make logs        — follow all logs  (ARGS='-s vllm' to filter)"

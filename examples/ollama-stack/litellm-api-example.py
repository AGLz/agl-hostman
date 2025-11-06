#!/usr/bin/env python3
"""
LiteLLM API Usage Examples for CT200 Ollama Stack

Demonstrates various ways to use LiteLLM proxy:
1. Direct API calls with requests
2. OpenAI-compatible SDK
3. LiteLLM Python SDK
4. Streaming responses
5. Multi-model requests
"""

import os
import json
import requests
from typing import Iterator, Dict, List

# Configuration
LITELLM_BASE_URL = os.getenv("LITELLM_BASE_URL", "http://10.6.0.17:4000")
LITELLM_API_KEY = os.getenv("LITELLM_API_KEY", "sk-1234")


# ============================================================================
# Example 1: Direct API Call with Requests
# ============================================================================
def example_direct_api():
    """Direct API call using requests library"""
    print("\n" + "=" * 80)
    print("Example 1: Direct API Call")
    print("=" * 80 + "\n")

    url = f"{LITELLM_BASE_URL}/chat/completions"
    headers = {
        "Authorization": f"Bearer {LITELLM_API_KEY}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": "qwen2.5-32b",
        "messages": [
            {"role": "system", "content": "You are a helpful AI assistant."},
            {"role": "user", "content": "Explain what is RAG in 2 sentences."},
        ],
        "temperature": 0.7,
        "max_tokens": 200,
    }

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        response.raise_for_status()

        result = response.json()
        answer = result["choices"][0]["message"]["content"]

        print(f"✅ Response received")
        print(f"📝 Answer: {answer}")
        print(f"📊 Tokens: {result['usage']}")

    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")


# ============================================================================
# Example 2: OpenAI-Compatible SDK
# ============================================================================
def example_openai_sdk():
    """Use OpenAI SDK with LiteLLM"""
    print("\n" + "=" * 80)
    print("Example 2: OpenAI-Compatible SDK")
    print("=" * 80 + "\n")

    try:
        import openai

        # Configure OpenAI client to use LiteLLM
        openai.api_base = LITELLM_BASE_URL
        openai.api_key = LITELLM_API_KEY

        response = openai.ChatCompletion.create(
            model="qwen2.5-32b",
            messages=[
                {"role": "user", "content": "What are the benefits of local LLMs?"}
            ],
            temperature=0.7,
            max_tokens=200,
        )

        answer = response.choices[0].message.content
        print(f"✅ Response received")
        print(f"📝 Answer: {answer}")

    except ImportError:
        print("⚠️  OpenAI SDK not installed: pip install openai")
    except Exception as e:
        print(f"❌ Error: {e}")


# ============================================================================
# Example 3: LiteLLM Python SDK
# ============================================================================
def example_litellm_sdk():
    """Use LiteLLM Python SDK"""
    print("\n" + "=" * 80)
    print("Example 3: LiteLLM Python SDK")
    print("=" * 80 + "\n")

    try:
        from litellm import completion

        response = completion(
            model="qwen2.5-32b",
            messages=[{"role": "user", "content": "Explain Docker in one sentence."}],
            api_base=LITELLM_BASE_URL,
            api_key=LITELLM_API_KEY,
            temperature=0.7,
            max_tokens=100,
        )

        answer = response.choices[0].message.content
        print(f"✅ Response received")
        print(f"📝 Answer: {answer}")

    except ImportError:
        print("⚠️  LiteLLM not installed: pip install litellm")
    except Exception as e:
        print(f"❌ Error: {e}")


# ============================================================================
# Example 4: Streaming Responses
# ============================================================================
def example_streaming():
    """Stream responses token by token"""
    print("\n" + "=" * 80)
    print("Example 4: Streaming Responses")
    print("=" * 80 + "\n")

    url = f"{LITELLM_BASE_URL}/chat/completions"
    headers = {
        "Authorization": f"Bearer {LITELLM_API_KEY}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": "qwen2.5-32b",
        "messages": [
            {
                "role": "user",
                "content": "Write a short poem about artificial intelligence.",
            }
        ],
        "stream": True,
        "temperature": 0.9,
        "max_tokens": 200,
    }

    try:
        print("📝 Streaming response:\n")
        with requests.post(
            url, headers=headers, json=payload, stream=True, timeout=60
        ) as response:
            response.raise_for_status()

            for line in response.iter_lines():
                if line:
                    line_text = line.decode("utf-8")
                    if line_text.startswith("data: "):
                        data = line_text[6:]  # Remove "data: " prefix
                        if data == "[DONE]":
                            break
                        try:
                            chunk = json.loads(data)
                            if "choices" in chunk and len(chunk["choices"]) > 0:
                                delta = chunk["choices"][0].get("delta", {})
                                if "content" in delta:
                                    print(delta["content"], end="", flush=True)
                        except json.JSONDecodeError:
                            pass

        print("\n\n✅ Streaming completed")

    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")


# ============================================================================
# Example 5: Multi-Model Comparison
# ============================================================================
def example_multi_model():
    """Query multiple models and compare responses"""
    print("\n" + "=" * 80)
    print("Example 5: Multi-Model Comparison")
    print("=" * 80 + "\n")

    models = ["qwen2.5-32b", "llama3.3", "mistral-7b"]
    question = "What is the main advantage of Docker containers?"

    results = {}

    for model in models:
        print(f"🤖 Testing model: {model}")

        url = f"{LITELLM_BASE_URL}/chat/completions"
        headers = {
            "Authorization": f"Bearer {LITELLM_API_KEY}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": model,
            "messages": [{"role": "user", "content": question}],
            "temperature": 0.7,
            "max_tokens": 150,
        }

        try:
            response = requests.post(url, headers=headers, json=payload, timeout=60)
            response.raise_for_status()

            result = response.json()
            answer = result["choices"][0]["message"]["content"]
            tokens = result["usage"]["total_tokens"]

            results[model] = {"answer": answer, "tokens": tokens}

            print(f"  ✅ Tokens used: {tokens}")
            print(f"  📝 Answer: {answer[:100]}...\n")

        except Exception as e:
            print(f"  ❌ Error: {e}\n")
            results[model] = {"error": str(e)}

    print("\n" + "=" * 80)
    print("Summary:")
    print("=" * 80)
    for model, result in results.items():
        if "error" not in result:
            print(f"\n{model}:")
            print(f"  Tokens: {result['tokens']}")
            print(f"  Answer: {result['answer']}")


# ============================================================================
# Example 6: Embeddings
# ============================================================================
def example_embeddings():
    """Generate embeddings using Ollama"""
    print("\n" + "=" * 80)
    print("Example 6: Text Embeddings")
    print("=" * 80 + "\n")

    url = f"{LITELLM_BASE_URL}/embeddings"
    headers = {
        "Authorization": f"Bearer {LITELLM_API_KEY}",
        "Content-Type": "application/json",
    }

    texts = [
        "Ollama is a tool for running LLMs locally.",
        "Docker containers provide isolated environments.",
        "RAG combines retrieval with generation.",
    ]

    payload = {"model": "nomic-embed-text", "input": texts}

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        response.raise_for_status()

        result = response.json()

        print(f"✅ Generated embeddings for {len(texts)} texts")
        print(f"📊 Embedding dimension: {len(result['data'][0]['embedding'])}")

        for i, text in enumerate(texts):
            embedding = result["data"][i]["embedding"]
            print(f"\n  Text {i+1}: {text}")
            print(f"  Embedding preview: [{embedding[0]:.4f}, {embedding[1]:.4f}, ...]")

    except requests.exceptions.RequestException as e:
        print(f"❌ Error: {e}")


# ============================================================================
# Example 7: Batch Requests
# ============================================================================
def example_batch_requests():
    """Send multiple requests in batch"""
    print("\n" + "=" * 80)
    print("Example 7: Batch Requests")
    print("=" * 80 + "\n")

    import concurrent.futures

    questions = [
        "What is Kubernetes?",
        "Explain microservices.",
        "What is CI/CD?",
        "Define Infrastructure as Code.",
    ]

    def query_model(question: str) -> Dict:
        """Query model with a question"""
        url = f"{LITELLM_BASE_URL}/chat/completions"
        headers = {
            "Authorization": f"Bearer {LITELLM_API_KEY}",
            "Content-Type": "application/json",
        }

        payload = {
            "model": "qwen2.5-32b",
            "messages": [{"role": "user", "content": question}],
            "temperature": 0.7,
            "max_tokens": 100,
        }

        try:
            response = requests.post(url, headers=headers, json=payload, timeout=60)
            response.raise_for_status()
            result = response.json()
            return {
                "question": question,
                "answer": result["choices"][0]["message"]["content"],
                "tokens": result["usage"]["total_tokens"],
            }
        except Exception as e:
            return {"question": question, "error": str(e)}

    print(f"🚀 Processing {len(questions)} questions in parallel...\n")

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        results = list(executor.map(query_model, questions))

    for i, result in enumerate(results, 1):
        print(f"Question {i}: {result['question']}")
        if "error" in result:
            print(f"  ❌ Error: {result['error']}")
        else:
            print(f"  ✅ Answer: {result['answer']}")
            print(f"  📊 Tokens: {result['tokens']}")
        print()


# ============================================================================
# Main Menu
# ============================================================================
def main():
    """Run examples"""
    print("\n" + "=" * 80)
    print("LiteLLM API Examples - CT200 Ollama Stack")
    print("=" * 80)

    examples = [
        ("Direct API Call", example_direct_api),
        ("OpenAI SDK", example_openai_sdk),
        ("LiteLLM SDK", example_litellm_sdk),
        ("Streaming", example_streaming),
        ("Multi-Model Comparison", example_multi_model),
        ("Text Embeddings", example_embeddings),
        ("Batch Requests", example_batch_requests),
    ]

    while True:
        print("\n" + "=" * 80)
        print("Select an example:")
        print("=" * 80)
        for i, (name, _) in enumerate(examples, 1):
            print(f"  {i}. {name}")
        print("  0. Exit")

        try:
            choice = input("\nEnter your choice: ").strip()

            if choice == "0":
                print("\n👋 Goodbye!")
                break

            idx = int(choice) - 1
            if 0 <= idx < len(examples):
                name, func = examples[idx]
                func()
                input("\n\nPress Enter to continue...")
            else:
                print("❌ Invalid choice")

        except ValueError:
            print("❌ Please enter a number")
        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break


if __name__ == "__main__":
    main()

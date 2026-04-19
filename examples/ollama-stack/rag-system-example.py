#!/usr/bin/env python3
"""
RAG System Example using Ollama + LangChain
Complete implementation for CT200 Ollama Stack

This example demonstrates how to build a production-ready RAG system using:
- Ollama for LLM inference (local)
- Nomic Embed Text for embeddings
- Chroma for vector storage
- LangChain for orchestration
"""

import os
from typing import List, Dict, Optional
from pathlib import Path

# LangChain imports
from langchain_community.llms import Ollama
from langchain_community.embeddings import OllamaEmbeddings
from langchain_community.vectorstores import Chroma
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
from langchain_community.document_loaders import (
    DirectoryLoader,
    TextLoader,
    UnstructuredMarkdownLoader,
)
from langchain.prompts import PromptTemplate
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler

# Configuration
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL", "http://10.6.0.17:11434")
LLM_MODEL = os.getenv("LLM_MODEL", "qwen2.5:32b")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "nomic-embed-text")
CHROMA_DB_PATH = os.getenv("CHROMA_DB_PATH", "./chroma_db")
DOCS_PATH = os.getenv("DOCS_PATH", "./docs")


class OllamaRAGSystem:
    """Production-ready RAG system using Ollama"""

    def __init__(
        self,
        ollama_base_url: str = OLLAMA_BASE_URL,
        llm_model: str = LLM_MODEL,
        embedding_model: str = EMBEDDING_MODEL,
        chroma_db_path: str = CHROMA_DB_PATH,
        streaming: bool = True,
    ):
        """
        Initialize RAG system

        Args:
            ollama_base_url: Ollama API endpoint
            llm_model: Model to use for generation
            embedding_model: Model to use for embeddings
            chroma_db_path: Path to Chroma vector database
            streaming: Enable streaming responses
        """
        self.ollama_base_url = ollama_base_url
        self.llm_model = llm_model
        self.embedding_model = embedding_model
        self.chroma_db_path = chroma_db_path
        self.streaming = streaming

        # Initialize components
        self._init_llm()
        self._init_embeddings()
        self._init_vectorstore()

    def _init_llm(self):
        """Initialize LLM"""
        callbacks = [StreamingStdOutCallbackHandler()] if self.streaming else []

        self.llm = Ollama(
            base_url=self.ollama_base_url,
            model=self.llm_model,
            temperature=0.7,
            callbacks=callbacks,
            verbose=False,
        )
        print(f"✅ LLM initialized: {self.llm_model}")

    def _init_embeddings(self):
        """Initialize embeddings"""
        self.embeddings = OllamaEmbeddings(
            base_url=self.ollama_base_url, model=self.embedding_model
        )
        print(f"✅ Embeddings initialized: {self.embedding_model}")

    def _init_vectorstore(self):
        """Initialize or load vector store"""
        if os.path.exists(self.chroma_db_path):
            self.vectorstore = Chroma(
                persist_directory=self.chroma_db_path,
                embedding_function=self.embeddings,
            )
            print(f"✅ Vector store loaded from: {self.chroma_db_path}")
        else:
            self.vectorstore = None
            print(f"⚠️  Vector store not found. Run ingest_documents() first.")

    def ingest_documents(
        self, docs_path: str = DOCS_PATH, file_pattern: str = "**/*.md"
    ):
        """
        Ingest documents into vector store

        Args:
            docs_path: Path to documents directory
            file_pattern: Glob pattern for files to load
        """
        print(f"📚 Loading documents from: {docs_path}")

        # Load documents
        loader = DirectoryLoader(
            docs_path, glob=file_pattern, loader_cls=UnstructuredMarkdownLoader
        )
        documents = loader.load()
        print(f"📄 Loaded {len(documents)} documents")

        # Split documents
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            length_function=len,
            separators=["\n\n", "\n", " ", ""],
        )
        texts = text_splitter.split_documents(documents)
        print(f"✂️  Split into {len(texts)} chunks")

        # Create vector store
        print("🔄 Creating vector embeddings...")
        self.vectorstore = Chroma.from_documents(
            documents=texts,
            embedding=self.embeddings,
            persist_directory=self.chroma_db_path,
        )
        self.vectorstore.persist()
        print(f"✅ Vector store created: {self.chroma_db_path}")

    def create_qa_chain(
        self,
        chain_type: str = "stuff",
        k: int = 5,
        return_source_docs: bool = True,
    ) -> RetrievalQA:
        """
        Create QA chain

        Args:
            chain_type: Type of chain ("stuff", "map_reduce", "refine")
            k: Number of documents to retrieve
            return_source_docs: Return source documents with answer

        Returns:
            RetrievalQA chain
        """
        if self.vectorstore is None:
            raise ValueError("Vector store not initialized. Run ingest_documents() first.")

        # Custom prompt template
        template = """Use the following pieces of context to answer the question at the end.
If you don't know the answer, just say that you don't know, don't try to make up an answer.

Context:
{context}

Question: {question}

Helpful Answer:"""

        prompt = PromptTemplate(
            template=template, input_variables=["context", "question"]
        )

        # Create retriever
        retriever = self.vectorstore.as_retriever(
            search_type="similarity", search_kwargs={"k": k}
        )

        # Create chain
        qa_chain = RetrievalQA.from_chain_type(
            llm=self.llm,
            chain_type=chain_type,
            retriever=retriever,
            return_source_documents=return_source_docs,
            chain_type_kwargs={"prompt": prompt},
        )

        return qa_chain

    def query(
        self, question: str, k: int = 5, return_sources: bool = True
    ) -> Dict[str, any]:
        """
        Query the RAG system

        Args:
            question: Question to ask
            k: Number of documents to retrieve
            return_sources: Include source documents in response

        Returns:
            Dictionary with answer and optional source documents
        """
        qa_chain = self.create_qa_chain(k=k, return_source_docs=return_sources)

        result = qa_chain({"query": question})

        response = {"answer": result["result"]}

        if return_sources and "source_documents" in result:
            response["sources"] = [
                {
                    "content": doc.page_content,
                    "metadata": doc.metadata,
                }
                for doc in result["source_documents"]
            ]

        return response

    def similarity_search(self, query: str, k: int = 5) -> List[Dict]:
        """
        Perform similarity search without LLM generation

        Args:
            query: Search query
            k: Number of results

        Returns:
            List of matching documents with metadata
        """
        if self.vectorstore is None:
            raise ValueError("Vector store not initialized")

        results = self.vectorstore.similarity_search(query, k=k)

        return [
            {
                "content": doc.page_content,
                "metadata": doc.metadata,
            }
            for doc in results
        ]


def main():
    """Example usage"""

    print("=" * 80)
    print("Ollama RAG System - CT200 Example")
    print("=" * 80)
    print()

    # Initialize RAG system
    rag = OllamaRAGSystem()

    # Check if documents are ingested
    if rag.vectorstore is None:
        print("📚 Vector store not found. Ingesting documents...")
        rag.ingest_documents(docs_path="../../docs")
        print()

    # Example queries
    queries = [
        "What is the WireGuard configuration for CT200?",
        "How do I access Archon MCP?",
        "What are the available Ollama models?",
        "Explain the network topology",
    ]

    for i, query in enumerate(queries, 1):
        print(f"\n{'=' * 80}")
        print(f"Query {i}: {query}")
        print(f"{'=' * 80}\n")

        result = rag.query(query, k=3, return_sources=True)

        print(f"\n📝 Answer:")
        print(result["answer"])

        if "sources" in result:
            print(f"\n📚 Sources ({len(result['sources'])} documents):")
            for j, source in enumerate(result["sources"], 1):
                print(f"\n  [{j}] {source['metadata'].get('source', 'Unknown')}")
                print(f"      {source['content'][:200]}...")

        print("\n" + "-" * 80)

        # Wait for user input
        input("\nPress Enter to continue to next query...")


if __name__ == "__main__":
    main()

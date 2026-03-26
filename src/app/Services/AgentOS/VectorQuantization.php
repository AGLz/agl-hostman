<?php

namespace App\Services\AgentOS;

/**
 * Vector Quantization Service
 *
 * Provides 50-87.5% memory reduction for vector embeddings.
 * Implements Product Quantization (PQ) for efficient storage.
 */
class VectorQuantization
{
    protected array $codebooks = [];

    protected int $codebookSize;

    protected float $compressionRatio;

    public function __construct(array $config)
    {
        $this->codebookSize = $config['codebook_size'];
        $this->compressionRatio = $config['compression_ratio'];
    }

    /**
     * Quantize vector using Product Quantization
     */
    public function quantize(array $vector): array
    {
        $subvectors = $this->splitSubvectors($vector);
        $quantized = [];

        foreach ($subvectors as $i => $subvector) {
            $codebook = $this->getCodebook($i);
            $centroidId = $this->findNearestCentroid($subvector, $codebook);
            $quantized[] = $centroidId;
        }

        return $quantized;
    }

    /**
     * Dequantize vector from PQ representation
     */
    public function dequantize(array $quantized): array
    {
        $vector = [];

        foreach ($quantized as $i => $centroidId) {
            $codebook = $this->getCodebook($i);
            $centroid = $codebook[$centroidId] ?? [];
            $vector = array_merge($vector, $centroid);
        }

        return $vector;
    }

    /**
     * Calculate memory savings
     */
    public function calculateSavings(int $vectorSize): array
    {
        $originalSize = $vectorSize * 4; // float32 = 4 bytes
        $compressedSize = count($this->splitSubvectors(array_fill(0, $vectorSize, 0))) * 1; // uint8 = 1 byte
        $ratio = $compressedSize / $originalSize;

        return [
            'original_bytes' => $originalSize,
            'compressed_bytes' => $compressedSize,
            'compression_ratio' => $ratio,
            'memory_reduction_pct' => (1 - $ratio) * 100,
        ];
    }

    /**
     * Split vector into subvectors for PQ
     */
    protected function splitSubvectors(array $vector): array
    {
        $numSubvectors = (int) (1 / $this->compressionRatio);
        $subvectorSize = (int) ceil(count($vector) / $numSubvectors);
        $subvectors = [];

        for ($i = 0; $i < $numSubvectors; $i++) {
            $start = $i * $subvectorSize;
            $subvectors[] = array_slice($vector, $start, $subvectorSize);
        }

        return $subvectors;
    }

    /**
     * Get or create codebook for subvector index
     */
    protected function getCodebook(int $index): array
    {
        if (! isset($this->codebooks[$index])) {
            $this->codebooks[$index] = $this->initializeCodebook();
        }

        return $this->codebooks[$index];
    }

    /**
     * Initialize codebook with random centroids
     */
    protected function initializeCodebook(): array
    {
        $codebook = [];

        for ($i = 0; $i < $this->codebookSize; $i++) {
            $codebook[] = $this->generateRandomCentroid();
        }

        return $codebook;
    }

    /**
     * Generate random centroid
     */
    protected function generateRandomCentroid(): array
    {
        $subvectorSize = (int) ceil(1536 / (1 / $this->compressionRatio));
        $centroid = [];

        for ($i = 0; $i < $subvectorSize; $i++) {
            $centroid[] = (mt_rand() / mt_getrandmax() - 0.5) * 2; // Range: -1 to 1
        }

        return $centroid;
    }

    /**
     * Find nearest centroid in codebook
     */
    protected function findNearestCentroid(array $subvector, array $codebook): int
    {
        $minDistance = INF;
        $nearestId = 0;

        foreach ($codebook as $id => $centroid) {
            $distance = $this->euclideanDistance($subvector, $centroid);
            if ($distance < $minDistance) {
                $minDistance = $distance;
                $nearestId = $id;
            }
        }

        return $nearestId;
    }

    /**
     * Calculate Euclidean distance
     */
    protected function euclideanDistance(array $a, array $b): float
    {
        $sum = 0;
        $len = min(count($a), count($b));

        for ($i = 0; $i < $len; $i++) {
            $sum += ($a[$i] - $b[$i]) ** 2;
        }

        return sqrt($sum);
    }

    /**
     * Train codebook using k-means
     */
    public function trainCodebook(int $subvectorIndex, array $trainingVectors, int $iterations = 10): void
    {
        $codebook = $this->getCodebook($subvectorIndex);

        for ($iter = 0; $iter < $iterations; $iter++) {
            // Assign vectors to nearest centroid
            $clusters = array_fill(0, $this->codebookSize, []);

            foreach ($trainingVectors as $vector) {
                $nearestId = $this->findNearestCentroid($vector, $codebook);
                $clusters[$nearestId][] = $vector;
            }

            // Update centroids
            foreach ($clusters as $clusterId => $vectors) {
                if (empty($vectors)) {
                    continue;
                }

                $mean = $this->calculateMean($vectors);
                $codebook[$clusterId] = $mean;
            }
        }

        $this->codebooks[$subvectorIndex] = $codebook;
    }

    /**
     * Calculate mean of vectors
     */
    protected function calculateMean(array $vectors): array
    {
        if (empty($vectors)) {
            return [];
        }

        $dim = count($vectors[0]);
        $mean = array_fill(0, $dim, 0);

        foreach ($vectors as $vector) {
            foreach ($vector as $i => $value) {
                $mean[$i] += $value;
            }
        }

        foreach ($mean as $i => $sum) {
            $mean[$i] = $sum / count($vectors);
        }

        return $mean;
    }

    /**
     * Get quantization statistics
     */
    public function stats(): array
    {
        return [
            'codebook_count' => count($this->codebooks),
            'codebook_size' => $this->codebookSize,
            'compression_ratio' => $this->compressionRatio,
            'memory_reduction_pct' => (1 - $this->compressionRatio) * 100,
        ];
    }

    /**
     * Serialize codebooks for storage
     */
    public function serialize(): string
    {
        return serialize($this->codebooks);
    }

    /**
     * Deserialize codebooks from storage
     */
    public function unserialize(string $data): void
    {
        $this->codebooks = unserialize($data);
    }

    /**
     * Clear all codebooks
     */
    public function clear(): void
    {
        $this->codebooks = [];
    }
}

package governance

data class KerEvidenceLattice(
    val knowledgeVerified: Long,
    val knowledgeUnresolved: Long,
    val engagementCompleted: Long,
    val engagementUnresolved: Long,
    val responsibilityVerified: Long,
    val responsibilityUnresolved: Long,
    val versionByNode: Map<String, Long>
) {
    init {
        require(knowledgeVerified >= 0L)
        require(knowledgeUnresolved >= 0L)
        require(engagementCompleted >= 0L)
        require(engagementUnresolved >= 0L)
        require(responsibilityVerified >= 0L)
        require(responsibilityUnresolved >= 0L)
        require(versionByNode.all { (nodeId, version) -> nodeId.isNotBlank() && version >= 0L })
    }

    fun merge(other: KerEvidenceLattice): KerEvidenceLattice {
        val mergedVersions = (versionByNode.keys + other.versionByNode.keys)
            .associateWith { nodeId ->
                maxOf(versionByNode[nodeId] ?: 0L, other.versionByNode[nodeId] ?: 0L)
            }

        return KerEvidenceLattice(
            knowledgeVerified = maxOf(knowledgeVerified, other.knowledgeVerified),
            knowledgeUnresolved = maxOf(knowledgeUnresolved, other.knowledgeUnresolved),
            engagementCompleted = maxOf(engagementCompleted, other.engagementCompleted),
            engagementUnresolved = maxOf(engagementUnresolved, other.engagementUnresolved),
            responsibilityVerified = maxOf(responsibilityVerified, other.responsibilityVerified),
            responsibilityUnresolved = maxOf(responsibilityUnresolved, other.responsibilityUnresolved),
            versionByNode = mergedVersions
        )
    }

    fun derivedKer(): KerView {
        return KerView(
            knowledgeFactor = ratio(knowledgeVerified, knowledgeUnresolved),
            engagementFactor = ratio(engagementCompleted, engagementUnresolved),
            responsibilityFactor = ratio(responsibilityVerified, responsibilityUnresolved)
        )
    }

    private fun ratio(positive: Long, unresolved: Long): Double {
        val denominator = positive.toDouble() + unresolved.toDouble()
        return if (denominator == 0.0) 0.0 else positive.toDouble() / denominator
    }
}

data class KerView(
    val knowledgeFactor: Double,
    val engagementFactor: Double,
    val responsibilityFactor: Double
) {
    init {
        require(knowledgeFactor in 0.0..1.0)
        require(engagementFactor in 0.0..1.0)
        require(responsibilityFactor in 0.0..1.0)
    }
}

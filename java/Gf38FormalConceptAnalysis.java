package org.augmentedhub.gf38;

import java.util.ArrayList;
import java.util.BitSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

public final class Gf38FormalConceptAnalysis {
    public record FormalContext(
            List<String> objects,
            List<String> attributes,
            List<Set<Integer>> objectAttributes
    ) {
        public FormalContext {
            Objects.requireNonNull(objects, "objects");
            Objects.requireNonNull(attributes, "attributes");
            Objects.requireNonNull(objectAttributes, "objectAttributes");

            if (objects.size() != objectAttributes.size()) {
                throw new IllegalArgumentException("Each object requires one attribute set.");
            }

            if (new LinkedHashSet<>(objects).size() != objects.size()
                    || new LinkedHashSet<>(attributes).size() != attributes.size()) {
                throw new IllegalArgumentException("Objects and attributes must be unique.");
            }

            for (Set<Integer> relation : objectAttributes) {
                for (Integer index : relation) {
                    if (index == null || index < 0 || index >= attributes.size()) {
                        throw new IllegalArgumentException("Attribute index is out of bounds.");
                    }
                }
            }
        }
    }

    public record FormalConcept(
            Set<String> extent,
            Set<String> intent
    ) {}

    public List<FormalConcept> enumerateConcepts(FormalContext context) {
        Objects.requireNonNull(context, "context");

        final List<FormalConcept> concepts = new ArrayList<>();
        BitSet intent = closureOfIntent(new BitSet(context.attributes().size()), context);

        while (intent != null) {
            final BitSet extent = deriveExtent(intent, context);
            concepts.add(new FormalConcept(
                    namesForObjects(extent, context),
                    namesForAttributes(intent, context)));

            intent = nextClosedIntent(intent, context);
        }

        return List.copyOf(concepts);
    }

    private static BitSet closureOfIntent(BitSet candidate, FormalContext context) {
        return deriveIntent(deriveExtent(candidate, context), context);
    }

    private static BitSet deriveExtent(BitSet intent, FormalContext context) {
        final BitSet extent = new BitSet(context.objects().size());

        for (int objectIndex = 0; objectIndex < context.objects().size(); objectIndex++) {
            final Set<Integer> assigned = context.objectAttributes().get(objectIndex);
            boolean containsAll = true;

            for (int attributeIndex = intent.nextSetBit(0);
                    attributeIndex >= 0;
                    attributeIndex = intent.nextSetBit(attributeIndex + 1)) {
                if (!assigned.contains(attributeIndex)) {
                    containsAll = false;
                    break;
                }
            }

            if (containsAll) {
                extent.set(objectIndex);
            }
        }

        return extent;
    }

    private static BitSet deriveIntent(BitSet extent, FormalContext context) {
        final BitSet intent = new BitSet(context.attributes().size());
        intent.set(0, context.attributes().size());

        if (extent.isEmpty()) {
            return intent;
        }

        for (int objectIndex = extent.nextSetBit(0);
                objectIndex >= 0;
                objectIndex = extent.nextSetBit(objectIndex + 1)) {
            final BitSet assigned = new BitSet(context.attributes().size());
            for (Integer attributeIndex : context.objectAttributes().get(objectIndex)) {
                assigned.set(attributeIndex);
            }
            intent.and(assigned);
        }

        return intent;
    }

    private static BitSet nextClosedIntent(BitSet current, FormalContext context) {
        final int attributeCount = context.attributes().size();

        for (int pivot = attributeCount - 1; pivot >= 0; pivot--) {
            if (!current.get(pivot)) {
                final BitSet candidate = (BitSet) current.clone();
                candidate.clear(pivot, attributeCount);
                candidate.set(pivot);

                final BitSet closed = closureOfIntent(candidate, context);
                if (isLecticallyGreater(current, closed, pivot)) {
                    return closed;
                }
            }
        }

        return null;
    }

    private static boolean isLecticallyGreater(BitSet current, BitSet candidate, int pivot) {
        if (!candidate.get(pivot)) {
            return false;
        }

        for (int index = 0; index < pivot; index++) {
            if (current.get(index) != candidate.get(index)) {
                return false;
            }
        }

        return true;
    }

    private static Set<String> namesForObjects(BitSet values, FormalContext context) {
        final Set<String> names = new LinkedHashSet<>();
        for (int index = values.nextSetBit(0);
                index >= 0;
                index = values.nextSetBit(index + 1)) {
            names.add(context.objects().get(index));
        }
        return Set.copyOf(names);
    }

    private static Set<String> namesForAttributes(BitSet values, FormalContext context) {
        final Set<String> names = new LinkedHashSet<>();
        for (int index = values.nextSetBit(0);
                index >= 0;
                index = values.nextSetBit(index + 1)) {
            names.add(context.attributes().get(index));
        }
        return Set.copyOf(names);
    }
}

"""Restricted canonical JSON bytes for an integer-only application profile.

Python 3.10 or newer; standard library only.

Not a full RFC 8785 implementation.
No semantic normalization, hashing, signing, storage, or network access.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

import json


PROFILE_VERSION = "world-save-jcs-integer-1"
MAX_BYTES = 1_048_576
MAX_DEPTH = 32
MAX_NODES = 10_000
MAX_INTEGER = 2**53 - 1


class ProfileError(ValueError):
    pass


def canonical_bytes(value):
    chunks = []
    total = 0
    nodes = 0

    def emit(text):
        nonlocal total
        try:
            data = text.encode("utf-8", errors="strict")
        except UnicodeEncodeError as error:
            raise ProfileError("invalid_unicode") from error

        total += len(data)
        if total > MAX_BYTES:
            raise ProfileError("output_size_limit")
        chunks.append(data)

    def string(text):
        try:
            size = len(text.encode("utf-8", errors="strict"))
        except UnicodeEncodeError as error:
            raise ProfileError("invalid_unicode") from error

        if size > MAX_BYTES:
            raise ProfileError("string_size_limit")

        return json.dumps(
            text,
            ensure_ascii=False,
            separators=(",", ":"),
            allow_nan=False,
        )

    def visit(item, depth):
        nonlocal nodes
        nodes += 1

        if depth > MAX_DEPTH or nodes > MAX_NODES:
            raise ProfileError("structure_limit")

        if item is None:
            emit("null")

        elif type(item) is bool:
            emit("true" if item else "false")

        elif type(item) is int:
            if abs(item) > MAX_INTEGER:
                raise ProfileError("integer_range")
            emit(str(item))

        elif type(item) is str:
            emit(string(item))

        elif type(item) is list:
            emit("[")
            for position, child in enumerate(item):
                if position:
                    emit(",")
                visit(child, depth + 1)
            emit("]")

        elif type(item) is dict:
            for key in item:
                if type(key) is not str:
                    raise ProfileError("string_keys_required")
                string(key)

            keys = sorted(
                item,
                key=lambda key: key.encode("utf-16-be", errors="strict"),
            )

            emit("{")
            for position, key in enumerate(keys):
                if position:
                    emit(",")
                emit(string(key))
                emit(":")
                visit(item[key], depth + 1)
            emit("}")

        else:
            raise ProfileError("unsupported_type")

    visit(value, 0)
    return b"".join(chunks)


def parse_and_canonicalize(text):
    if type(text) is not str:
        raise ProfileError("json_text_required")

    try:
        size = len(text.encode("utf-8", errors="strict"))
    except UnicodeEncodeError as error:
        raise ProfileError("invalid_unicode") from error

    if size > MAX_BYTES:
        raise ProfileError("input_size_limit")

    depth = 0
    quoted = False
    escaped = False

    for char in text:
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char in "[{":
            depth += 1
            if depth > MAX_DEPTH:
                raise ProfileError("parse_depth_limit")
        elif char in "]}":
            depth -= 1

    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ProfileError("duplicate_key")
            result[key] = value
        return result

    def integer(token):
        if len(token) > 17:
            raise ProfileError("integer_range")
        value = int(token)
        if abs(value) > MAX_INTEGER:
            raise ProfileError("integer_range")
        return value

    def reject_number(token):
        raise ProfileError("non_integer_number_not_supported")

    try:
        value = json.loads(
            text,
            object_pairs_hook=pairs,
            parse_int=integer,
            parse_float=reject_number,
            parse_constant=reject_number,
        )
    except json.JSONDecodeError as error:
        raise ProfileError("invalid_json") from error

    return canonical_bytes(value)

// SPDX-License-Identifier: MIT OR Apache-2.0
#ifndef LUA_HOST_COMPAT_HPP
#define LUA_HOST_COMPAT_HPP

#include <cstddef>

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#if LUA_VERSION_NUM != 504 && LUA_VERSION_NUM != 505
#error "This adapter supports Lua 5.4 and Lua 5.5 headers only."
#endif

namespace lua_host_compat {

enum class LoadState {
    loaded,
    syntax_error,
    allocation_error,
    invalid_request,
    source_limit,
    stack_unavailable,
    other_lua_error
};

struct LoadReport {
    LoadState state;
    int lua_status;
    int stack_delta;
};

struct BuildProfile {
    int header_version;
    std::size_t integer_bytes;
    std::size_t number_bytes;
    bool explicit_state_seed;
};

inline constexpr BuildProfile build_profile() noexcept {
    return {
        LUA_VERSION_NUM,
        sizeof(lua_Integer),
        sizeof(lua_Number),
#if LUA_VERSION_NUM == 505
        true
#else
        false
#endif
    };
}

// The allocator and its userdata must outlive the state and all
// associated allocation-release paths.
//
// The seed is a runtime/hash seed, not a credential nonce generator.
// Lua 5.4's public constructor has no corresponding seed argument.
inline lua_State* create_state(
    lua_Alloc allocator,
    void* userdata,
    unsigned int seed
) {
    if (allocator == nullptr) {
        return nullptr;
    }

#if LUA_VERSION_NUM == 505
    return lua_newstate(allocator, userdata, seed);
#else
    (void)seed;
    return lua_newstate(allocator, userdata);
#endif
}

// Requires a valid state on an owned host thread.
//
// On successful compilation, one compiled function remains on the stack.
// On Lua compilation failure, one error value normally remains.
// Host-side request rejection leaves the stack unchanged.
//
// The function is not executed here.
// Default environment attachment by Lua is not an isolation guarantee.
// Replace/verify the environment before invoking the loaded chunk.
//
// No raw error text is copied into LoadReport.
inline LoadReport load_text_snapshot(
    lua_State* state,
    const char* bytes,
    std::size_t length,
    std::size_t maximum_source_bytes
) {
    if (state == nullptr || (bytes == nullptr && length != 0)) {
        return {LoadState::invalid_request, -1, 0};
    }

    const int before = lua_gettop(state);

    if (length > maximum_source_bytes) {
        return {LoadState::source_limit, -1, 0};
    }

    if (!lua_checkstack(state, 1)) {
        return {LoadState::stack_unavailable, -1, 0};
    }

    const char* source = bytes != nullptr ? bytes : "";
    const int status = luaL_loadbufferx(
        state,
        source,
        length,
        "=approved_text_snapshot",
        "t"
    );
    const int delta = lua_gettop(state) - before;

    switch (status) {
    case LUA_OK:
        return {LoadState::loaded, status, delta};
    case LUA_ERRSYNTAX:
        return {LoadState::syntax_error, status, delta};
    case LUA_ERRMEM:
        return {LoadState::allocation_error, status, delta};
    default:
        return {LoadState::other_lua_error, status, delta};
    }
}

} // namespace lua_host_compat

#endif

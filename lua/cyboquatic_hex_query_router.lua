local Router = {}

local valid_edge = {
    [0] = true,
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
}

local function is_nonempty_string(value)
    return type(value) == "string" and value:match("%S") ~= nil
end

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function valid_anchor_id(value)
    return is_nonempty_string(value)
        and #value >= 8
        and #value <= 128
        and value:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end

local function bind_anchor_id(value)
    if not valid_anchor_id(value) then
        return nil, "anchor_id must match the local stable identifier grammar"
    end
    return value
end

function Router.nearby_anchor_query(request)
    if type(request) ~= "table" then
        return nil, "request must be a table"
    end

    if not is_finite_number(request.min_x_m)
        or not is_finite_number(request.max_x_m)
        or not is_finite_number(request.min_y_m)
        or not is_finite_number(request.max_y_m) then
        return nil, "bounding coordinates must be finite numbers"
    end

    if request.min_x_m > request.max_x_m
        or request.min_y_m > request.max_y_m then
        return nil, "bounding coordinate minima must not exceed maxima"
    end

    local corridor_id = request.corridor_id
    if corridor_id ~= nil and not is_nonempty_string(corridor_id) then
        return nil, "corridor_id must be omitted or a non-empty string"
    end

    return {
        sql = [[
            SELECT
                anchor.anchor_id,
                anchor.grid_id,
                anchor.corridor_id,
                anchor.basin_crs,
                anchor.geometry_revision,
                anchor.cell_q,
                anchor.cell_r,
                anchor.center_x_m,
                anchor.center_y_m
            FROM cyboquatic_hex_anchor_rtree AS spatial
            JOIN cyboquatic_hex_anchor AS anchor
              ON anchor.anchor_row_id = spatial.anchor_row_id
            WHERE spatial.min_x_m >= :min_x_m
              AND spatial.max_x_m <= :max_x_m
              AND spatial.min_y_m >= :min_y_m
              AND spatial.max_y_m <= :max_y_m
              AND anchor.record_status = 'active'
              AND (:corridor_id IS NULL OR anchor.corridor_id = :corridor_id)
            ORDER BY anchor.corridor_id, anchor.cell_q, anchor.cell_r
        ]],
        parameters = {
            min_x_m = request.min_x_m,
            max_x_m = request.max_x_m,
            min_y_m = request.min_y_m,
            max_y_m = request.max_y_m,
            corridor_id = corridor_id,
        },
    }
end

function Router.shared_edge_query(anchor_id, edge_index)
    local bound_anchor_id, anchor_error = bind_anchor_id(anchor_id)
    if not bound_anchor_id then
        return nil, anchor_error
    end

    if not valid_edge[edge_index] then
        return nil, "edge_index must be an integer in the closed interval [0, 5]"
    end

    return {
        sql = [[
            SELECT
                source.anchor_id AS source_anchor_id,
                source.corridor_id,
                source.grid_id,
                source.basin_crs,
                source.geometry_revision,
                claim.edge_index,
                neighbor.anchor_id AS neighbor_anchor_id,
                neighbor.cell_q AS neighbor_cell_q,
                neighbor.cell_r AS neighbor_cell_r,
                reverse_claim.claim_id AS reciprocal_claim_id
            FROM cyboquatic_hex_edge_claim AS claim
            JOIN cyboquatic_hex_anchor AS source
              ON source.anchor_row_id = claim.anchor_row_id
            JOIN cyboquatic_hex_anchor AS neighbor
              ON neighbor.anchor_row_id = claim.neighbor_anchor_row_id
            LEFT JOIN cyboquatic_hex_edge_claim AS reverse_claim
              ON reverse_claim.anchor_row_id = neighbor.anchor_row_id
             AND reverse_claim.neighbor_anchor_row_id = source.anchor_row_id
             AND reverse_claim.edge_index = ((claim.edge_index + 3) % 6)
             AND reverse_claim.claim_status = 'active'
            WHERE source.anchor_id = :anchor_id
              AND claim.edge_index = :edge_index
              AND source.record_status = 'active'
              AND neighbor.record_status = 'active'
              AND claim.claim_status = 'active'
        ]],
        parameters = {
            anchor_id = bound_anchor_id,
            edge_index = edge_index,
        },
    }
end

function Router.corridor_residual_query(corridor_id, observed_utc)
    if not is_nonempty_string(corridor_id) then
        return nil, "corridor_id must be a non-empty string"
    end

    if type(observed_utc) ~= "string"
        or observed_utc:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") == nil then
        return nil, "observed_utc must use UTC RFC 3339 second precision"
    end

    return {
        sql = [[
            SELECT
                corridor_id,
                observed_utc,
                r_affine,
                all_segments_within_limit,
                segment_count
            FROM cyboquatic_corridor_residual_summary
            WHERE corridor_id = :corridor_id
              AND observed_utc = :observed_utc
        ]],
        parameters = {
            corridor_id = corridor_id,
            observed_utc = observed_utc,
        },
    }
end

return Router

---------------------------------------------------------------------------
-- The `align` layout has three slots for child widgets. On its main axis, it
-- will use as much space as is available to it and distribute that to its child
-- widgets by stretching or shrinking them based on the chosen @{expand}
-- strategy.
-- On its secondary axis, the biggest child widget determines the size of the
-- layout, but smaller widgets will not be stretched to match it.
--
-- In its default configuration, the layout will give the first and third
-- widgets only the minimum space they ask for and it aligns them to the outer
-- edges. The remaining space between them is made available to the widget in
-- slot two.
--
-- This layout is most commonly used to split content into left/top, center and
-- right/bottom sections. As such, it is usually seen as the root layout in
-- @{awful.wibar}.
--
-- You may also fill just one or two of the widget slots, the @{expand} algorithm
-- will adjust accordingly.
--
--@DOC_wibox_layout_defaults_align_EXAMPLE@
--
-- @author Uli Schlachter
-- @copyright 2010 Uli Schlachter
-- @layoutmod wibox.layout.align
-- @supermodule wibox.widget.base
---------------------------------------------------------------------------

local table = table
local pairs = pairs
local type = type
local floor = math.floor
local gtable = require("gears.table")
local base = require("wibox.widget.base")

local align = {}


-- The names of the modes how the align layout spaces and sizes
-- its child widgets.
--
-- It can be used instead of specifying the mode with strings
--
-- @table expand_modes
align.expand_modes = {
    INSIDE    = "inside",
    OUTSIDE   = "outside",
    NONE      = "none",
    JUSTIFIED = "justified"
}


-- Calculate the layout of an align layout.
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function align:layout(context, width, height)
    local result = {}
    local is_vert = self._private.dir == "y"
    local size_remains = is_vert and height or width
    local first = self._private.first
    local second = self._private.second
    local third = self._private.third

    -- Get the required size of a widget
    local function fit_widget(widget, max_size)
        -- Can't fit a widget if it does not exist
        if not widget then
            return 0
        end

        max_size = max_size and max_size or size_remains
        local width_remains = is_vert and width or max_size
        local height_remains = is_vert and max_size or height

        local w, h = base.fit_widget(
            self, context, widget,
            width_remains, height_remains
        )
        return is_vert and h or w
    end
    -- Place a widget inside the layout
    local function place_widget(widget, offset, size)
        -- Can't place a widget if it does not exist or there is no more size
        if not widget or size_remains <= 0 then
            return
        end

        offset = floor(offset)
        if not size then
            size = floor(fit_widget(widget, size_remains))
        else
            size = floor(size)
            fit_widget(widget, size)
        end

        local child_width = is_vert and width or size
        local child_height = is_vert and size or height

        local x_offset = (not is_vert) and offset or 0
        local y_offset = (not is_vert) and 0 or offset

        table.insert(
            result,
            base.place_widget_at(
                widget,
                x_offset, y_offset,
                child_width, child_height
            )
        )

        size_remains = size_remains - size
    end

    -- Size of the layout before any placements
    local size_total = size_remains

    if self._private.expand == align.expand_modes.NONE then
        local size_second = fit_widget(second)

        if size_second >= size_total then
            -- Second widget takes all layout's space, no need to place another widgets
            place_widget(second, 0, size_total)
        elseif size_second == 0 then
            -- There is no second widget
            local size_side = floor(size_total / 2)

            local size_first = fit_widget(first, size_side)
            place_widget(
                first,
                -- At the beginning
                0,
                -- Takes the space it needs until the second widget
                size_first
            )

            place_widget(
                third,
                -- At the end
                size_total - fit_widget(third)
            )
        else
            -- Second widget can leave some space to other widgets
            local size_side = floor((size_total - size_second) / 2)

            place_widget(
                first,
                -- At the beginning
                0,
                -- Takes the space it needs until the second widget
                fit_widget(first, size_side)
            )

            local size_third = fit_widget(third, size_side)
            place_widget(
                third,
                -- At the end
                size_total - size_third,
                -- Takes the space it needs after the second widget
                size_third
            )

            place_widget(
                second,
                -- After first
                size_side,
                -- Takes the space it needs
                size_second
            )
        end
    elseif self._private.expand == align.expand_modes.OUTSIDE then
        local size_second = fit_widget(second)

        if size_second >= size_total then
            -- Second widget takes all layout's space, no need to place another widgets
            place_widget(second, 0, size_total)
        else
            -- Second widget can leave some space to other widgets
            local size_side = floor((size_remains - size_second) / 2)

            place_widget(
                first,
                -- At the beginning
                0,
                -- Takes the space it needs until the second widget
                size_side
            )

            place_widget(
                third,
                -- At the end
                size_total - size_side,
                -- Takes the space it needs after the second widget
                size_side
            )

            place_widget(
                second,
                -- After first
                size_side
                -- Takes all available space - expand
            )
        end
    elseif self._private.expand == align.expand_modes.JUSTIFIED then
        local size_first = fit_widget(first)
        local size_second = fit_widget(second)
        local size_third = fit_widget(third)
        local max_size_side = math.max(size_first, size_third)
        local min_size_side = math.min(size_first, size_third)
        local first_larger = size_first >= size_third

        if max_size_side + min_size_side >= size_total then
            -- Could place at least one side widget
            -- The other side widget will be ignored if no space left

            if first_larger then
                place_widget(
                    first,
                    -- At the beginning
                    0
                    -- Takes the space it needs
                )
                place_widget(
                    third,
                    -- After the first
                    size_first,
                    -- Whatever is left - shrink
                    size_remains
                )
            else
                place_widget(
                    third,
                    -- At the end
                    size_total - size_third
                    -- Takes the space it needs
                )
                place_widget(
                    first,
                    -- At the beginning
                    0
                    -- Whatever is left - shrink
                )
            end
        elseif max_size_side * 2 + size_second >= size_total then
            -- Could place a bit of the second widget
            -- If do not fully expand the smaller widget

            if first_larger then
                place_widget(
                    -- At the beginning
                    first,
                    -- Takes the space it needs
                    0
                )

                -- Whatever second widget would leave it if the third would be placed
                size_third = math.max(size_remains - size_second, size_third)
                place_widget(
                    third,
                    -- At the end
                    size_total - size_third,
                    -- Size calculated above - expand
                    size_third
                )

                place_widget(
                    second,
                    -- After the first
                    size_first,
                    -- Whatever is left - shrink
                    size_remains
                )
            else
                place_widget(
                    third,
                    -- At the end
                    size_total - size_third
                    -- Takes the space it needs
                )

                -- Whatever second widget would leave it if the first would be placed
                size_first = math.max(size_remains - size_second, size_first)
                place_widget(
                    first,
                    -- At the beginning
                    0,
                    -- Size calculated above - expand
                    size_first
                )

                place_widget(
                    second,
                    -- After the first
                    size_first,
                    -- Whatever is left - shrink
                    size_remains
                )
            end
        else
            -- Can place all widgets with the correct sizes

            place_widget(
                -- At the beginning
                first,
                0,
                -- Same size as the largest widget - expand
                max_size_side
            )

            place_widget(
                third,
                -- At the end
                size_total - max_size_side,
                -- Same size as the largest widget - expand
                max_size_side
            )

            place_widget(
                second,
                -- After the first
                max_size_side,
                -- Whatever is left - expand
                size_remains
            )
        end
    else
        local size_first = fit_widget(first)
        place_widget(
            first,
            -- At the beginning
            0
            -- Takes the space it needs
        )

        place_widget(
            third,
            -- At the end
            size_total - fit_widget(third)
            -- Takes the space it needs
        )

        place_widget(
            second,
            -- After first
            size_first,
            -- Takes all available space - expand
            size_remains
        )
    end

    return result
end

--- The widget in slot one.
--
-- This is the widget that is at the left/top.
--
-- @property first
-- @tparam widget first
-- @propemits true false
function align:set_first(widget)
    if self._private.first == widget then
        return
    end
    self._private.first = widget
    self:emit_signal("widget::layout_changed")
    self:emit_signal("property::first", widget)
end

--- The widget in slot two.
--
-- This is the centered one.
--
-- @property second
-- @tparam widget second
-- @propemits true false
function align:set_second(widget)
    if self._private.second == widget then
        return
    end
    self._private.second = widget
    self:emit_signal("widget::layout_changed")
    self:emit_signal("property::second", widget)
end

--- The widget in slot three.
--
-- This is the widget that is at the right/bottom.
--
-- @property third
-- @tparam widget third
-- @propemits true false
function align:set_third(widget)
    if self._private.third == widget then
        return
    end
    self._private.third = widget
    self:emit_signal("widget::layout_changed")
    self:emit_signal("property::third", widget)
end

for _, prop in ipairs {"first", "second", "third", "expand" } do
    align["get_"..prop] = function(self)
        return self._private[prop]
    end
end

function align:get_children()
    return gtable.from_sparse {self._private.first, self._private.second, self._private.third}
end

function align:set_children(children)
    self:set_first(children[1])
    self:set_second(children[2])
    self:set_third(children[3])
end

-- Fit the align layout into the given space. The align layout will
-- ask for the sum of the sizes of its sub-widgets in its direction
-- and the largest sized sub widget in the other direction.
-- @param context The context in which we are fit.
-- @param orig_width The available width.
-- @param orig_height The available height.
function align:fit(context, orig_width, orig_height)
    local used_in_dir = 0
    local used_in_other = 0

    for _, v in pairs{self._private.first, self._private.second, self._private.third} do
        local w, h = base.fit_widget(self, context, v, orig_width, orig_height)

        local max = self._private.dir == "y" and w or h
        if max > used_in_other then
            used_in_other = max
        end

        used_in_dir = used_in_dir + (self._private.dir == "y" and h or w)
    end

    if self._private.dir == "y" then
        return used_in_other, used_in_dir
    end
    return used_in_dir, used_in_other
end

--- Set the expand mode, which determines how child widgets expand to take up
-- unused space.
--
-- The following values are valid:
--
-- * `"inside"`: The widgets in slot one and three are set to their minimal
--   required size. The widget in slot two is then given the remaining space.
--   This is the default behaviour.
-- * `"outside"`: The widget in slot two is set to its minimal required size and
--   placed in the center of the space available to the layout. The other
--   widgets are then given the remaining space on either side.
--   If the center widget requires all available space, the outer widgets are
--   not drawn at all.
-- * `"justified"`: The widgets in the slot one and three are set to the same
--   size, which the size of the largest between the two. The second widget takes
--   the remaining space in the middle. The longest side widget gets priority
-- * `"none"`: All widgets are given their minimal required size or the
--   remaining space, whichever is smaller. The center widget gets priority.
--
-- Attempting to set any other value than one of those three will fall back to
-- `"inside"`.
--
-- @property expand
-- @tparam[opt="inside"] string mode How to use unused space.
function align:set_expand(mode)
    if gtable.hasitem(align.expand_modes, mode) then
        self._private.expand = mode
    else
        self._private.expand = align.expand_modes.INSIDE
    end
    self:emit_signal("widget::layout_changed")
    self:emit_signal("property::expand", mode)
end

function align:reset()
    for _, v in pairs({ "first", "second", "third" }) do
        self[v] = nil
    end
    self:emit_signal("widget::layout_changed")
end

local function get_layout(dir, first, second, third)
    local ret = base.make_widget(nil, nil, {enable_properties = true})
    ret._private.dir = dir

    for k, v in pairs(align) do
        if type(v) == "function" then
            rawset(ret, k, v)
        end
    end

    ret:set_expand("inside")
    ret:set_first(first)
    ret:set_second(second)
    ret:set_third(third)

    -- An align layout allow set_children to have empty entries
    ret.allow_empty_widget = true

    return ret
end

--- Returns a new horizontal align layout.
--
-- The three widget slots are aligned left, center and right.
--
-- Additionally, this creates the aliases `set_left`, `set_middle` and
-- `set_right` to assign @{first}, @{second} and @{third} respectively.
-- @constructorfct wibox.layout.align.horizontal
-- @tparam[opt] widget left Widget to be put in slot one.
-- @tparam[opt] widget middle Widget to be put in slot two.
-- @tparam[opt] widget right Widget to be put in slot three.
function align.horizontal(left, middle, right)
    local ret = get_layout("x", left, middle, right)

    rawset(ret, "set_left"  , ret.set_first  )
    rawset(ret, "set_middle", ret.set_second )
    rawset(ret, "set_right" , ret.set_third  )

    return ret
end

--- Returns a new vertical align layout.
--
-- The three widget slots are aligned top, center and bottom.
--
-- Additionally, this creates the aliases `set_top`, `set_middle` and
-- `set_bottom` to assign @{first}, @{second} and @{third} respectively.
-- @constructorfct wibox.layout.align.vertical
-- @tparam[opt] widget top Widget to be put in slot one.
-- @tparam[opt] widget middle Widget to be put in slot two.
-- @tparam[opt] widget bottom Widget to be put in slot three.
function align.vertical(top, middle, bottom)
    local ret = get_layout("y", top, middle, bottom)

    rawset(ret, "set_top"   , ret.set_first  )
    rawset(ret, "set_middle", ret.set_second )
    rawset(ret, "set_bottom", ret.set_third  )

    return ret
end

--@DOC_fixed_COMMON@

return align

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80

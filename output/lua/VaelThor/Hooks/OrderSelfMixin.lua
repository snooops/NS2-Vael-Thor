-- ============================================================================
-- Vael'Thor Empire - guard for clientless players (post-hook of lua/OrderSelfMixin.lua)
--
-- OrderSelfMixin:_UpdateOrderSelf (timed, once a second) calls
-- self:GetClient():GetIsVirtual() without a nil check. Players created with the
-- "spawn <class>" cheat have no client, so it errored every second. Treat them
-- like bots: stop the auto-order timer.
-- ============================================================================
if OrderSelfMixin and not VT_HookedOrderSelfMixin then
VT_HookedOrderSelfMixin = true
local oldUpdate = OrderSelfMixin._UpdateOrderSelf
function OrderSelfMixin:_UpdateOrderSelf(...)
    if self.GetClient and self:GetClient() == nil then
        return false            -- halt the timed callback
    end
    return oldUpdate(self, ...)
end
end -- VT_HookedOrderSelfMixin

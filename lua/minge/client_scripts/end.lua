local values = debug.getupvalues(minge.Callbacks.PostDrawTranslucentRenderables or function() end)
values.DrawPlayerHitbox = function() end

for name, _ in pairs(minge.Callbacks) do
	minge:Off(name)
end

rawset(minge, "Aimbot", function() end)
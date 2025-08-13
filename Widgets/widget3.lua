function widget:GetInfo()
  return {
    name    = "EpicMenu_Integration_Test",
    desc    = "Verifies Epic Menu toggle integration — native pattern",
    author  = "ChatGPT",
    version = "1.4",
    enabled = true,  -- Always enabled, logic gated by toggle
  }
end

-- Epic Menu checkbox
options = {
  {
    key    = 'test_toggle',
    name   = 'Run Test Logic',
    desc   = 'Toggle the behavior of this test widget.',
    type   = 'bool',
    value  = false,
    scope  = 'widget',
  },
}

function widget:Update()
  if options[1].value then
    Spring.Echo("[EpicMenu_Integration_Test] Running update logic...")
    -- Your logic here
  end
end

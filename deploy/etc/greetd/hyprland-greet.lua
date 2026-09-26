-- Minimal Hyprland config for the greetd greeter session.
hl.monitor({
  output = " ",
  mode = "preferred",
  position = "auto",
  scale = 1,
})
hl.on("hyprland.start", function()
  hl.exec_cmd("qs -p /etc/greetd/quickshell-greeter")
end)

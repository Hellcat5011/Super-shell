# Super Shell 🚀

A minimal, feature-rich shell environment built with [Quickshell](https://quickshell.outfoxxed.me/) for Hyprland.

> [!WARNING]
> **Vibe Coded Project:** This is a fully vibe-coded project. If you are uncomfortable with this, please ignore this repository.

## ✨ Features

Super Shell provides a comprehensive set of built-in tools and menus to keep your desktop lightweight and functional:

- **App Launcher**: Quickly find and launch your applications.
- **Wallpaper Selector**: Easily switch between your favorite backgrounds.
- **Power Menu**: Sleek system controls (shutdown, reboot, suspend, etc.).
- **Notification Center**: Manage and view your system notifications.
- **Clipboard Manager**: A full, lightweight clipboard manager written entirely in QML (no reliance on `cliphist`).
- **Screenshot & Screen Record Utility**: Capture your screen effortlessly.
- **Lockscreen**: Custom lockscreen interface *(currently in development, planned integration with greetd)*.

## 📦 Dependencies

Ensure you have the following installed on your system before proceeding:

- **[Quickshell](https://quickshell.outfoxxed.me/)**: The core QML shell environment powering Super Shell.
- **[Hyprland](https://hyprland.org/)**: The Wayland compositor (the shell heavily relies on `hyprctl`).
- **awww**: Used for setting wallpapers (can be swapped out for `hyprpaper` if preferred).
- **magick (ImageMagick)**: Required for generating application launcher preview images.
- **matugen**: Used for Material You dynamic theme generation based on your wallpaper.
- **systemd / logind**: Required for power menu actions via `loginctl` and `systemctl`.

## 🛠️ Installation

1. **Install Quickshell**: Follow the instructions on the [Quickshell website](https://quickshell.outfoxxed.me/) to install it for your distribution.
2. **Clone the repository**: Download this configuration to your Quickshell config directory.
   ```sh
   git clone <repository_url> ~/.config/quickshell/super-shell
   ```
   *(If you've already cloned it, simply move the `super-shell` folder to `~/.config/quickshell/`)*
3. **Run the shell**:
   ```sh
   qs -c super-shell
   ```

## 🎮 Usage & IPC Calls

Super Shell is controlled via Quickshell's Inter-Process Communication (IPC). You can bind the following commands in your Hyprland configuration (`hyprland.conf`) to toggle various menus.

### Available Commands:

- **App Launcher**: `qs -c super-shell ipc call launcher toggle`
- **Wallpaper Selector**: `qs -c super-shell ipc call wallpaper toggle`
- **Clipboard Manager**: `qs -c super-shell ipc call clipboard toggle`
- **Power Menu**: `qs -c super-shell ipc call power toggle`
- **Notification Center**: `qs -c super-shell ipc call notif toggle`
- **Screenshot Utility**: `qs -c super-shell ipc call screenshot toggle`
- **Lock Screen**: `qs -c super-shell ipc call lock lock`

### Help

For more information about available IPC calls and extended options, run:

```sh
qs -c super-shell ipc call help display
```

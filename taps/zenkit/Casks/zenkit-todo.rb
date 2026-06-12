cask "zenkit-todo" do
  arch arm: "arm64", intel: "x64"

  version :latest
  sha256 :no_check

  url "https://static.zenkit.com/downloads/desktop-apps/todo/zenkit-todo-mac-#{arch}.dmg"
  name "Zenkit To Do"
  desc "To-do list and task management app"
  homepage "https://zenkit.com/en/todo/"

  app "Zenkit To Do.app"

  zap trash: [
    "~/Library/Application Support/zenkit-todo",
    "~/Library/Preferences/com.zenkit.todo.desktop.plist",
  ]
end

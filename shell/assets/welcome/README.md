# Welcome Widget Assets

This directory contains the assets and configuration used by the `WelcomeWidget` module to display "What's New" updates to the user.

## File Locations

* **Features JSON** (`shell/assets/welcome/features.json`): The core configuration file that defines all the features and updates shown in the Welcome Widget.
* **Media Assets** (`shell/assets/welcome/`): Any images, GIFs, or videos referenced by `features.json` should typically be placed in this directory (or relatively referenced from it).
* **State File** (`~/.local/share/caelestia/state/seen_features.txt`):
The Welcome Widget tracks which features the user has already acknowledged by saving their IDs to a local state file. 
If a feature ID is present in this file, it will no longer be shown in the startup screen or the "What's New" page. 



## JSON Format

> [!IMPORTANT]  
> **Use a unique suffix for the ID!**  
> When creating or updating a feature entry, append a unique suffix to its `id` to guarantee it is globally unique and ensures users see the new prompt. Since git commit hashes aren't known until *after* you commit, here are the best alternatives:
> * **Date Suffix (Recommended)**: Append the date you added the feature (e.g., `feature_name_20231024`).
> * **Version Suffix**: Append the target release version (e.g., `feature_name_v2_4`).
> * **PR/Issue Number**: If applicable, use the pull request or issue tracker number (e.g., `feature_name_pr42`).

The `features.json` file uses the following structure. It expects a single `features` array containing objects for each update item.


* `id` (string): A unique identifier for the feature. **Important:** The widget tracks seen features by their `id`.
* `title` (string): The headline displayed in the list and header.
* `description` (string): The full detailed text shown when the feature is clicked.
* `icon` (string, optional): A Material icon string to display alongside the item.
* `media_url` (string, optional): A relative path to the media file to display.


Example:

```json
{
  "features": [
    {
      "id": "welcome_widget_intro_a1b2c3d4",
      "title": "Welcome to Caelestia Updates",
      "description": "Whenever we introduce exciting new features, they will appear here...",
      "icon": "celebration",
      "media_url": "../badapple.mp4"
    }
  ]
}
```

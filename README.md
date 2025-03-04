# DotNetDataCollectorEx

**DotNetDataCollectorEx** is an extension/replacement to Cheat Engine's **DotNetDataCollector**, designed to work with **.NET Framework 4.5+** and **.NET Core 3+** / **.NET 5+**. It provides some additional features and in some cases more information. It also supports **.NET 8+** which Cheat Engines's **DotNetDataCollector** does not.

**DotNetDataCollectorEx** uses [ClrMD](https://github.com/microsoft/clrmd) to collect information whereas Cheat Engine's **DotNetDataCollector** uses the **.NET Unmanaged API**

## Features

- Support for **.NET Framework 4.5+** and **.NET Core 3+** / **.NET 5+**.
- Provides, in some cases, more detailed memory analysis and additional functions compared to the legacy **DotNetDataCollector**.
- Works in both **Replacement Mode** and **Extension Mode**.
- Can be used dynamically via Lua to replace the legacy **DotNetDataCollector**.

---

## Installation

There are two installation methods for **DotNetDataCollectorEx**:

### **1. Replacement Mode (Recommended in most cases unless you never or rarely use it for .net8+ targets)**

1. Locate your **Cheat Engine** installation folder.
2. Rename the existing **DotNetDataCollector32.exe** and **DotNetDataCollector64.exe** to **LegacyDotNetDataCollector32.exe** **LegacyDotNetDataCollector64.exe** respectively.
  - **DotNetDataCollectorEx** will automatically run `LegacyDotNetDataCollector.exe` for older .NET versions or Versions for which it can't find the DAC.
4. Copy `DotNetDataCollectorEx32.exe` and `DotNetDataCollectorEx64.exe` into **Cheat Engine's** installation folder and rename them to `DotNetDataCollector32.exe` and `DotNetDataCollector64.exe` respectively.
5. (OPTIONAL) Copy `DotNetDataCollectorEx.lua` into the `autorun` folder.
6. Restart **Cheat Engine**.

Now, Cheat Engine will start the **DotNetDataCollectorEx** which will under normal circumstances forward everything to the Legacy DotNetDataCollector unless it can't be used on the target (**.net8+**) or it breaks in which case it will use **DotNetDataCollectorEx**.
If you place the `DotNetDataCollectorEx.lua` file into the `autorun` folder then you can also use the Extended functionality in **.net Framework 4.5+** targets.

### **2. Extension Mode (Recommended if you only want the extra functionality or rarely target .net8+ targets)**

1. Keep the existing **DotNetDataCollector.exe's** in place.
2. Copy `DotNetDataCollectorEx32.exe` and `DotNetDataCollectorEx64.exe` into one of the folders defined in the lua script inside the `processlocations` table.
   - Default Locations are:
   - 1. **Cheat Engine** installation folder
     2. `autorun` folder
     3. `autorun\dlls` folder
   - These can be changed inside the lua Script.
4. Copy `DotNetDataCollectorEx.lua` into `Cheat Engine\autorun\`.
5. Restart **Cheat Engine**.

In this mode:
- **DotNetDataCollectorEx** runs alongside the legacy **DotNetDataCollector**.
- You can **dynamically replace the legacy collector** later using a Lua function. For more info refer to [this section](#replace-legacy-datacollector-using-lua)
- Replacing the **legacy collector** will only work on the **lua side**! This means that the **symbol handler** and **Data Disector** (**currently**) won't work!

### **Replace Legacy DataCollector Using Lua**
- `ReplaceLegacyDataCollector(restore)`
- A method of the object returned by `getDotNetDataCollectorEx()`.
- Should only be used/required if you use it in **Extension Mode** and not **Replacement Mode**.
- Replaces the legacy **DotNetDataCollector** with **DotNetDataCollectorEx** at runtime.
- Use this function to switch to the new collector for **.NET 8+** applications.
- If you want to restore the legacy **DotNetDataCollector** you can call this function with `restore` being `true`
- Do note that this will only replace it on the **lua side**!
- If used in **Extension Mode** then the **symbol handler** and **Data Disector** (**currently**) won't work (give no info)!

- #### Example Usage in Lua:
```lua
local collectorEx = getDotNetDataCollectorEx()  -- Get the new collector object
collectorEx.ReplaceLegacyDataCollector()        -- Replace the old collector with the new one for .NET 8+

if (true) -- Optional reinitialize the DotNetSymbolHandler so the Disassembler shows the Names of Methods
  createThread(function () -- Do it async so it doesn't block the main thread freezing Cheat Engine
    reinitializeDotNetSymbolhandler()
  end)
end
```

---

## Recommended Usage

# Using **DotNetDataCollectorEx** in **Replacement Mode** provides the following benefits:
- Will by default still use the **Legacy DotNetDataCollector** unless it can't (**.net 8+**) or the **Legacy DotNetDataCollector** breaks.
- Cheat Engines **Symbol Handler** and **Data Disector** work and provide info even on **.net 8+** targets.
- Can use extra functions if the `DotNetDataCollectorEx.lua` file is placed inside the `autorun` folder.

# Using **DotNetDataCollectorEx** in **Extension Mode** provides the following benefits:
- No need to replace exectuables.

If you want to debug **.NET 8+** applications in **Extension Mode**, then it is **recommended** to call `ReplaceLegacyDataCollector` to replace the legacy collector, as the legacy version does not support **.NET 8+**. This is important because other **Cheat Engine** functionality that relies on **DotNetDataCollector** will only work with **.NET 8+** if you use the new version. These include but are not limited to:
- The `.net Info` Window
- `dotnetinterface.lua` used for example for Jitting methods.

---

## Limitations and Compatibility

- **Legacy DotNetDataCollector**:
  - Works for **.NET Framework versions older than 4.5**.
  - **Does not support .NET 8+**.

- **DotNetDataCollectorEx**:
  - Supports **.NET Framework 4.5+** and is the only version that supports **.NET 8+**.
  - Provides, in some cases, more detailed memory analysis and additional features compared to the legacy version.

- **Extension Mode**
  - **Cheat Engine's** Symbol Handler does not work. This means no Symbols in the `Memory View` window.
  - **Cheat Engine's** Dissect data/structures doed not work. This means no info provided for structures. So no fields are automatically filled and no name is automatically given to the structure.

### Known Limitations:
- Certain operations may incur slightly higher performance overhead compared to the legacy collector.
- **Parameter Names** returned by `getMethodParameters` are not the **actual** name of the parameter but the name of the type. This is because [ClrMD](https://github.com/microsoft/clrmd) does not expose those.
- **DotNetDataCollectorEx** seems to miss some **types(classes)** that Cheat Engine's **DotNetDataCollector** finds. This is as far as I understand because [ClrMD](https://github.com/microsoft/clrmd) is only able to find **constructed types**. Though in **my testing** it found **most** types and **all** that where actually useful to me.

---

## Lua API
DotNetDataCollectorEx provides additional Lua functions that can be used inside Cheat Engine.  
For a full list of available functions and their descriptions, refer to the [Lua API Reference](LUA_API.md).

---

## Building from Source

To compile **DotNetDataCollectorEx** from source, you will need:

- **.NET 8 SDK** installed on your system  
- **Visual Studio 2022** (or any other preferred build environment)  

---

### 📌 Building with Visual Studio 2022

1. **Clone the repository**:
   ```sh
   git clone https://github.com/Bloodyboneye/DotNetDataCollectorEx
   cd DotNetDataCollectorEx
   ```

2. **Open the solution** (`DotNetDataCollectorEx.sln`) in **Visual Studio 2022**.

3. **Select the desired build configuration**:
   - **Release | x64** for `win-x64`
   - **Debug | x64** for `win-x64-debug`
   - **Release | x86** for `win-x86`
   - **Debug | x86** for `win-x86-debug`

4. **Publish the project**:
   - Open **Solution Explorer**, right-click the **DotNetDataCollectorEx** project, and select **Publish**.
   - Choose the desired **publish profile** (`win-x64`, `win-x86`, etc.).
   - Click **Publish**.

5. **Find the compiled executable** in the respective output directory ([see the table below](#-output-directories))

---

### 📌 Building with Command Line (CLI)

1. **Clone the repository**:
   ```sh
   git clone https://github.com/Bloodyboneye/DotNetDataCollectorEx
   cd DotNetDataCollectorEx
   ```

2. **Restore dependencies**:
   ```sh
   dotnet restore
   ```

3. **Build and publish** using the desired profile:

   - **Win-x64 (Release)**:
     ```sh
     dotnet publish -c Release -r win-x64 --self-contained false -o bin/publish/
     ```
   - **Win-x64 (Debug)**:
     ```sh
     dotnet publish -c Debug -r win-x64 --self-contained false -o bin/publish/debug/
     ```
   - **Win-x64 (Self-Contained)**:
     ```sh
     dotnet publish -c Release -r win-x64 --self-contained true -o bin/publish/self-contained/
     ```
   - **Win-x86 (Release)**:
     ```sh
     dotnet publish -c Release -r win-x86 --self-contained false -o bin/publish/
     ```
   - **Win-x86 (Debug)**:
     ```sh
     dotnet publish -c Debug -r win-x86 --self-contained false -o bin/publish/debug/
     ```
   - **Win-x86 (Self-Contained)**:
     ```sh
     dotnet publish -c Release -r win-x86 --self-contained true -o bin/publish/self-contained/
     ```

---

### 📌 Output Directories

| Publish Profile          | Target Platform | Build Type | Output Directory              |
|--------------------------|-----------------|------------|-------------------------------|
| `win-x64`                | x64             | Release    | `bin/publish/`                |
| `win-x64-debug`          | x64             | Debug      | `bin/publish/debug/`          |
| `win-x64-selfcontained`  | x64             | Release    | `bin/publish/self-contained/` |
| `win-x86`                | x86             | Release    | `bin/publish/`                |
| `win-x86-debug`          | x86             | Debug      | `bin/publish/debug/`          |
| `win-x86-selfcontained`  | x86             | Release    | `bin/publish/self-contained/` |

After publishing, the compiled executables will be named:
- **`DotNetDataCollectorEx64.exe`** for x64 builds
- **`DotNetDataCollectorEx32.exe`** for x86 builds

---

### License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE.txt) for details.

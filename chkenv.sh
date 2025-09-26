#!/usr/bin/env bash

# 定義需要檢查的套件列表
REQUIRED_PACKAGES=(
    neovim
    zsh
    python3
    python3-pip # Debian/apt 專用套件名稱
    tmux
    git
    curl
    unzip
    pipx
    gh
    most
    autojump
    eza
    rcm
)

# 檢查作業系統類型並設定套件管理器變數
OS=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PACKAGE_MANAGER="brew"
    INSTALL_CMD_BASE="brew install"
elif command -v apt &> /dev/null; then
    OS="debian"
    PACKAGE_MANAGER="apt"
    INSTALL_CMD_BASE="apt install -y"
else
    echo "錯誤：此腳本僅支援 macOS (Homebrew) 及 Debian-based 系統 (apt)。"
    exit 1
fi

echo "偵測到 $OS 系統。開始檢查依賴套件..."

MISSING_PACKAGES=()
PACKAGES_TO_INSTALL=()
# 新增一個旗標 (Flag) 來追蹤 Neovim 的狀態
NEOVIM_IS_INSTALLED=false

# --------------------------
# macOS 專用：檢查並安裝 Hack Nerd Font 字體 (Debian 不執行此函數)
# --------------------------
check_and_install_nerd_font() {
    # ... (此函數未變動)
    if fc-list : family | grep -i "Hack Nerd Font" >/dev/null 2>&1 || \
       ls "$HOME/Library/Fonts/Hack Regular Nerd Font Complete.ttf" >/dev/null 2>&1; then
        echo "✅ Hack Nerd Font 已安裝。"
        return 0
    fi

    echo "⚠️ 未偵測到 Hack Nerd Font。正在嘗試下載並安裝..."

    local FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip"
    local TEMP_DIR=$(mktemp -d)
    local ZIP_FILE="$TEMP_DIR/Hack.zip"
    local FONT_DIR="$HOME/Library/Fonts"

    mkdir -p "$FONT_DIR"

    if ! curl -L "$FONT_URL" -o "$ZIP_FILE"; then
        echo "❌ 錯誤：下載 Hack Nerd Font 失敗。"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    if ! unzip -o "$ZIP_FILE" -d "$TEMP_DIR"; then
        echo "❌ 錯誤：解壓縮 Hack Nerd Font 失敗。"
        rm -rf "$TEMP_DIR"
        return 1
    fi

    find "$TEMP_DIR" -maxdepth 1 -name "*.ttf" -exec cp {} "$FONT_DIR" \;

    rm -rf "$TEMP_DIR"

    echo "✅ Hack Nerd Font 已成功安裝到 $FONT_DIR。"
}


# --------------------------
# 處理 macOS 系統
# --------------------------
if [ "$OS" == "macos" ]; then
    # 1. 檢查 Homebrew
    if ! command -v brew &> /dev/null; then
        echo "錯誤：未偵測到 Homebrew (brew)。請先安裝 Homebrew："
        echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi

    # 檢查套件
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        # 排除在 macOS 上通常非獨立 Homebrew formulae 的項目
        if [ "$pkg" == "python3-pip" ]; then
            continue
        fi
        
        # 使用 brew list 檢查是否由 Homebrew 安裝
        if ! brew list --formula | grep -q "^$pkg\$"; then
            MISSING_PACKAGES+=("$pkg")
            PACKAGES_TO_INSTALL+=("$pkg")
        fi
    done

    # 執行字體檢查與安裝
    check_and_install_nerd_font
    
# --------------------------
# 處理 Debian 系統 (已修正使用 dpkg -s 檢查狀態)
# --------------------------
elif [ "$OS" == "debian" ]; then
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        # *** 修正後的檢查邏輯：確保套件狀態為 'install ok installed' ***
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            MISSING_PACKAGES+=("$pkg")
            PACKAGES_TO_INSTALL+=("$pkg")
        else
            # 如果 nvim 已經安裝，設置旗標
            if [ "$pkg" == "neovim" ]; then
                NEOVIM_IS_INSTALLED=true
            fi
        fi
    done
fi

# --------------------------
# 輸出結果 / 自動安裝
# --------------------------
echo "---"
if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
    # 情況一：所有套件都已安裝
    echo "所有必需的軟體套件都已安裝。腳本將繼續執行..."
    
    # 只有 Debian 系統需要額外設定 nvim
    if [ "$OS" == "debian" ] && [ "$NEOVIM_IS_INSTALLED" == true ]; then
        echo "偵測到 neovim 已安裝。嘗試設定其為預設編輯器..."
        # 執行 update-alternatives
        if [ "$EUID" -eq 0 ]; then
             update-alternatives --set editor /usr/bin/nvim
             echo "✅ neovim 已成功設定為系統預設編輯器。"
        else
             echo "提示：若要將 neovim 設定為系統預設編輯器，請手動執行："
             echo "sudo update-alternatives --set editor /usr/bin/nvim"
        fi
    fi
    exit 0
else
    # 情況二：有套件遺失
    # 去除重複項並建立最終指令所需的套件列表
    UNIQUE_PACKAGES=$(printf "%s\n" "${PACKAGES_TO_INSTALL[@]}" | awk '!a[$0]++' | tr '\n' ' ')

    echo "以下軟體套件尚未安裝 (共 ${#MISSING_PACKAGES[@]} 個)："
    printf "  - %s\n" "${MISSING_PACKAGES[@]}"
    echo ""

    if [ "$OS" == "debian" ]; then
        # 檢查是否為 Root 權限
        if [ "$EUID" -eq 0 ]; then
            echo "偵測到 Root 權限 (\$EUID=0)。開始自動安裝缺少的套件..."
            INSTALL_COMMAND="apt update && $INSTALL_CMD_BASE $UNIQUE_PACKAGES"
            echo "執行：$INSTALL_COMMAND"

            # 自動執行安裝命令
            if eval "$INSTALL_COMMAND"; then
                echo "✅ 所有缺少的套件已成功安裝。"
                echo "設定 neovim 為預設編輯器..."
                update-alternatives --set editor /usr/bin/nvim
                echo "✅ neovim 已成功設定為系統預設編輯器。"
                fi
                exit 0
            else
                echo "❌ 警告：套件安裝失敗，請檢查錯誤訊息。"
                exit 1
            fi
        else
            echo "偵測到非 Root 權限。請手動執行以下指令安裝所有缺少的套件："
            echo ""
            INSTALL_COMMAND="sudo apt update && sudo $INSTALL_CMD_BASE $UNIQUE_PACKAGES"
            echo "$INSTALL_COMMAND" 
            
            # 如果 nvim 包含在安裝列表中，提示使用者設定
            if [[ " ${PACKAGES_TO_INSTALL[@]} " =~ " neovim " ]]; then
                echo "並接著執行以下指令來設定 neovim 為預設編輯器："
                echo "sudo update-alternatives --set editor /usr/bin/nvim"
            fi

            echo ""
            exit 1
        fi
    elif [ "$OS" == "macos" ]; then
        # macOS 採用自動安裝 (Homebrew 通常不需要 sudo)
        echo "偵測到 macOS 系統。開始使用 Homebrew 自動安裝缺少的套件..."
        echo "執行：$INSTALL_CMD_BASE $UNIQUE_PACKAGES"

        # 自動執行安裝命令
        if $INSTALL_CMD_BASE $UNIQUE_PACKAGES; then
            echo "✅ 所有缺少的套件已成功安裝。"
            exit 0
        else
            echo "❌ 警告：套件安裝失敗，請檢查錯誤訊息。"
            echo "請確認您的 Homebrew 環境已正確設定。"
            exit 1
        fi
    fi
fi

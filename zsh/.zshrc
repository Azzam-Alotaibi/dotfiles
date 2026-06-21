export PATH="/opt/homebrew/opt/postgresql@13/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
alias pp='pnpm'
alias c='code'
alias gg='go get .'
alias cptree="tree -I 'node_modules|.git|dist' | pbcopy"
alias lg='lazygit'
alias tn='tmux new-session -s'
alias tl='tmux list-sessions'
alias ta='tmux attach-session'
export PATH="/usr/local/mysql/bin:$PATH"
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export COLORTERM=truecolor
export EDITOR="zed --wait"
export VISUAL="zed --wait"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

. "$HOME/.local/bin/env"

autoload -U add-zsh-hook
tmux-git-autofetch() {($HOME/.config/tmux/plugins/tmux-git-autofetch/git-autofetch.tmux --current &)}
add-zsh-hook chpwd tmux-git-autofetch


# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Haskell
export PATH="$HOME/.ghcup/bin:$PATH"

# Expo
export EXPO_PACKAGE_MANAGER=pnpm

# Android studio
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Use viu to display image
function view-image() {
  viu "$1"
}

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# expo versioning BS
# ---------- shared helpers ----------

_vlog()  { echo "  ✓ $1"; }
_vwarn() { echo "⚠️  $1"; }
_verr()  { echo "❌ $1" >&2; }

_check_node() {
  if ! command -v node >/dev/null 2>&1; then
    _verr "node is not installed or not in PATH. Install Node.js first."
    return 1
  fi
}

_check_json() {
  node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$1" 2>/dev/null || {
    _verr "Invalid JSON: $1"
    return 1
  }
}

_find_project_root() {
  local dir="$PWD"
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    [ -f "$dir/app.json" ] && { echo "$dir"; return 0; }
    dir=$(dirname "$dir")
  done
  [ -f "$HOME/app.json" ] && { echo "$HOME"; return 0; }
  return 1
}

# sets: _PROOT _APP _PBX _GRADLE _EAS
_resolve_paths() {
  _check_node || return 1

  _PROOT=$(_find_project_root) || {
    _verr "No app.json found from $PWD up to $HOME."
    return 1
  }
  _APP="$_PROOT/app.json"
  _check_json "$_APP" || return 1

  _PBX=$(ls -d "$_PROOT"/ios/*.xcodeproj/project.pbxproj 2>/dev/null | head -1)
  _GRADLE="$_PROOT/android/app/build.gradle"
  _EAS="$_PROOT/eas.json"

  [ -z "$_PBX" ]      && _vwarn "iOS project not found (ios/*.xcodeproj) — iOS will be skipped."
  [ ! -f "$_GRADLE" ] && _vwarn "Android not found ($_GRADLE) — Android will be skipped."

  if [ -z "$_PBX" ] && [ ! -f "$_GRADLE" ]; then
    _verr "Neither iOS nor Android native project found. Nothing to update."
    return 1
  fi

  [ -n "$_PBX" ]    && [ ! -w "$_PBX" ]    && { _verr "No write permission: $_PBX"; return 1; }
  [ -f "$_GRADLE" ] && [ ! -w "$_GRADLE" ] && { _verr "No write permission: $_GRADLE"; return 1; }
  [ ! -w "$_APP" ]  && { _verr "No write permission: $_APP"; return 1; }
  return 0
}

# fails if zero matches. args: pattern replacement file label
_sed_verified() {
  local pattern="$1" repl="$2" file="$3" label="$4"
  local count
  count=$(grep -Ec "$pattern" "$file" 2>/dev/null)
  if [ "${count:-0}" -eq 0 ]; then
    _verr "Pattern for '$label' not found in $file. Nothing changed (possible misconfigured target/widget)."
    return 1
  fi
  sed -i '' "s/$pattern/$repl/g" "$file" || { _verr "sed failed on $file"; return 1; }
  _vlog "$label updated ($count match(es)) in $(basename "$file")"
}

# ---------- bump build number ----------

expo_bump_build() {
  _resolve_paths || return 1

  local current
  current=$(node -e "
    const a=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));
    const b=a.expo && a.expo.ios && a.expo.ios.buildNumber;
    if(b===undefined||b===null){process.stderr.write('MISSING');process.exit(2);}
    if(!/^[0-9]+\$/.test(String(b))){process.stderr.write('NONINT');process.exit(3);}
    process.stdout.write(String(b));
  " "$_APP") || {
    case $? in
      2) _verr "expo.ios.buildNumber missing in app.json. Set it (e.g. \"1\") before bumping." ;;
      3) _verr "expo.ios.buildNumber is not a plain integer string. Fix it manually first." ;;
      *) _verr "Failed to read buildNumber from app.json." ;;
    esac
    return 1
  }

  local new=$((current + 1))
  local failed=0

  if [ -n "$_PBX" ]; then
    _sed_verified "CURRENT_PROJECT_VERSION = [0-9]*;" "CURRENT_PROJECT_VERSION = $new;" "$_PBX" "iOS CURRENT_PROJECT_VERSION" || failed=1
  fi
  if [ -f "$_GRADLE" ]; then
    _sed_verified "versionCode [0-9]*" "versionCode $new" "$_GRADLE" "Android versionCode" || failed=1
  fi

  # only sync app.json if native edits succeeded
  if [ "$failed" -eq 0 ]; then
    node -e "
      const fs=require('fs');const a=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));
      const n=Number(process.argv[2]);
      a.expo.ios=a.expo.ios||{};a.expo.android=a.expo.android||{};
      a.expo.ios.buildNumber=String(n);a.expo.android.versionCode=n;
      fs.writeFileSync(process.argv[1],JSON.stringify(a,null,2)+'\n');
    " "$_APP" "$new" && _vlog "app.json updated" \
      || { _verr "Failed to write app.json."; failed=1; }
  fi

  if [ "$failed" -eq 0 ]; then
    echo "[$_PROOT] ✅ Build bumped: $current -> $new"
  else
    _verr "[$_PROOT] Build bump completed WITH ERRORS (state may be inconsistent — review above)."
    return 1
  fi
}

# ---------- set marketing version ----------

expo_set_version() {
  if [ -z "$1" ]; then _verr "Usage: expo_set_version <x.y.z>"; return 1; fi
  if ! echo "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    _verr "Invalid version '$1'. Expected format: x.y.z (e.g. 1.2.0)."
    return 1
  fi
  _resolve_paths || return 1

  local v="$1" failed=0

  if [ -n "$_PBX" ]; then
    _sed_verified "MARKETING_VERSION = [^;]*;" "MARKETING_VERSION = $v;" "$_PBX" "iOS MARKETING_VERSION" || failed=1
  fi
  if [ -f "$_GRADLE" ]; then
    _sed_verified "versionName \"[^\"]*\"" "versionName \"$v\"" "$_GRADLE" "Android versionName" || failed=1
  fi

  if [ "$failed" -eq 0 ]; then
    node -e "
      const fs=require('fs');const a=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));
      a.expo.version=process.argv[2];
      fs.writeFileSync(process.argv[1],JSON.stringify(a,null,2)+'\n');
    " "$_APP" "$v" && _vlog "app.json updated" \
      || { _verr "Failed to write app.json."; failed=1; }
  fi

  if [ "$failed" -eq 0 ]; then
    echo "[$_PROOT] ✅ Marketing version set to $v"
  else
    _verr "[$_PROOT] Version set completed WITH ERRORS (state may be inconsistent — review above)."
    return 1
  fi
}

# ---------- one-time setup ----------

expo_setup_versioning() {
  _resolve_paths || return 1
  local failed=0

  if [ -n "$_PBX" ]; then
    if [ ! -x /usr/libexec/PlistBuddy ]; then
      _vwarn "PlistBuddy not found — skipping plist linking."
    else
      local ios_dir; ios_dir=$(dirname "$(dirname "$_PBX")")
      local found=0
      while IFS= read -r plist; do
        found=1
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString \$(MARKETING_VERSION)" "$plist" 2>/dev/null \
          || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string \$(MARKETING_VERSION)" "$plist" \
          || { _verr "Failed setting CFBundleShortVersionString in $plist"; failed=1; }
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion \$(CURRENT_PROJECT_VERSION)" "$plist" 2>/dev/null \
          || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string \$(CURRENT_PROJECT_VERSION)" "$plist" \
          || { _verr "Failed setting CFBundleVersion in $plist"; failed=1; }
        _vlog "linked vars in $plist"
      done < <(find "$ios_dir" -name "Info.plist")
      [ "$found" -eq 0 ] && _vwarn "No Info.plist files found under $ios_dir."
    fi
  fi

  if [ -f "$_EAS" ]; then
    _check_json "$_EAS" || { _verr "eas.json is invalid JSON — skipping EAS config."; failed=1; }
    if [ "$failed" -eq 0 ]; then
      node -e "
        const fs=require('fs');const e=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));
        e.cli=e.cli||{};e.cli.appVersionSource='local';
        e.build=e.build||{};
        for(const p of Object.values(e.build)){if(p&&typeof p==='object')p.autoIncrement=false;}
        fs.writeFileSync(process.argv[1],JSON.stringify(e,null,2)+'\n');
      " "$_EAS" && _vlog "eas.json: appVersionSource=local, autoIncrement=false" \
        || { _verr "Failed to write eas.json."; failed=1; }
    fi
  else
    _vwarn "eas.json not found — skipping EAS config."
  fi

  if [ "$failed" -eq 0 ]; then
    echo "[$_PROOT] ✅ Setup complete. CFBundleSignature left untouched."
  else
    _verr "[$_PROOT] Setup completed WITH ERRORS — review above."
    return 1
  fi
}

# ---------- set build number ----------

expo_set_build() {
  if [ -z "$1" ]; then _verr "Usage: expo_set_build <integer>"; return 1; fi
  if ! echo "$1" | grep -Eq '^[0-9]+$'; then
    _verr "Invalid build number '$1'. Expected a plain integer (e.g. 42)."
    return 1
  fi
  _resolve_paths || return 1

  local new="$1" failed=0

  if [ -n "$_PBX" ]; then
    _sed_verified "CURRENT_PROJECT_VERSION = [0-9]*;" "CURRENT_PROJECT_VERSION = $new;" "$_PBX" "iOS CURRENT_PROJECT_VERSION" || failed=1
  fi
  if [ -f "$_GRADLE" ]; then
    _sed_verified "versionCode [0-9]*" "versionCode $new" "$_GRADLE" "Android versionCode" || failed=1
  fi

  if [ "$failed" -eq 0 ]; then
    node -e "
      const fs=require('fs');const a=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));
      const n=Number(process.argv[2]);
      a.expo.ios=a.expo.ios||{};a.expo.android=a.expo.android||{};
      a.expo.ios.buildNumber=String(n);a.expo.android.versionCode=n;
      fs.writeFileSync(process.argv[1],JSON.stringify(a,null,2)+'\n');
    " "$_APP" "$new" && _vlog "app.json updated" \
      || { _verr "Failed to write app.json."; failed=1; }
  fi

  if [ "$failed" -eq 0 ]; then
    echo "[$_PROOT] ✅ Build number set to $new"
  else
    _verr "[$_PROOT] Build set completed WITH ERRORS (state may be inconsistent — review above)."
    return 1
  fi
}

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

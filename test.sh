#!/usr/bin/env bash
set -euo pipefail

# 📦 Variables
mkdir -p "./test_tmp"
WORKDIR=$(readlink -f "./test_tmp")
ORIGIN="$WORKDIR/tiddlygit-origin.git"
CLONE="$WORKDIR/tiddlygit"

kill_tiddlywiki() {
	echo "Killing tiddlywiki.jl"
  pid=$(pgrep -ofa -x "node ./node_modules/tiddlywiki/tiddlywiki.js Wikis/BobWiki/ --wsserver" | cut -d" " -f 1)
  if [ -n "$pid" ]; then
    kill "$pid"
  else
    echo "PID not found"
  fi
}

cleanup() {
  echo "🧹 Cleaning up..."
	set +e
  kill_tiddlywiki
}
trap cleanup EXIT

echo "📁 Temporary working directory: $WORKDIR"

# 1. 💾 Local bare mirror
mkdir -p "$(dirname "$ORIGIN")"
if [[ ! -d "$ORIGIN" ]]; then
  echo "🔧 Cloning the original repository (bare)"
  git clone --bare https://github.com/dionisos2/tiddlygit.git "$ORIGIN"
else
  echo "🔄 Updating the mirror repository"
  (cd "$ORIGIN" && git fetch origin)
fi

# 2. 📥 Test clone
echo "📥 Cloning for testing"
git -C "$CLONE" pull || git clone "$ORIGIN" "$CLONE"
cd "$CLONE"
git remote set-url origin "$ORIGIN"

# 3. 🛠 Installation and server
echo "📦 Installation"
chmod +x installation.sh run.sh synchronize.sh
./installation.sh

echo "🚀 Starting the TiddlyGit server"
./run.sh &
# Note: run.sh starts a background server, PID != $!
sleep 1  # initial wait
# Wait via port check + ensure server is available
for i in {1..20}; do
  curl -fs http://localhost:7070/ && break
  sleep 1
  echo "⏳ Waiting for the server..."
done
curl -fs http://localhost:7070/ || { echo "❌ Server did not start"; exit 1; }
echo "✅ Server is up"

# 4. 🧪 Conflict management test

echo "🧪 Creating conflict management"

cd "$CLONE"
# Create a test tiddler
printf "\n\nbob conflict" >> Wikis/BobWiki/tiddlers/test.tid

# 1st synchronization (initial push)
./synchronize.sh
sleep 2
kill_tiddlywiki

# Reset to previous HEAD state
git reset --hard HEAD^

# Simulate conflict
printf "\n\ninstance conflict" >> Wikis/BobWiki/tiddlers/test.tid

# 2nd call => should trigger a conflict
./synchronize.sh
sleep 2
kill_tiddlywiki

# 🕵️‍♂️ Verify the file created by tiddly-merge
echo "📁 Searching for tiddlers tagged with GitConflict..."
CONFLICT_FILES=$(grep -lR "GitConflict" Wikis/BobWiki/tiddlers/ | grep -v "/GitConflict.tid$" || true)

if [[ -z "${CONFLICT_FILES:-}" ]]; then
  echo "❌ No tiddler with GitConflict tag found — merge driver did not work"
  exit 1
fi

echo "✅ Merge driver generated the following files:"
echo "$CONFLICT_FILES"
echo "Deleting $WORKDIR"
rm -rf "$WORKDIR"
echo "✅ Test completed successfully"

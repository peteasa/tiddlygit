#!/usr/bin/env bash
set -euo pipefail

# 📦 Variables
mkdir -p "./test_tmp"
WORKDIR=$(readlink -f "./test_tmp")
ORIGIN="$WORKDIR/tiddlygit-origin.git"
CLONE="$WORKDIR/tiddlygit"
INST="$WORKDIR/instance"

kill_tiddlywiki() {
	echo "Kill tiddlywiki.jl"
	pid=$(pgrep -ofa -x "node ./node_modules/tiddlywiki/tiddlywiki.js Wikis/BobWiki/ --wsserver" | cut -d" " -f 1)
	if [ "$pid" != "" ]
	then
		kill "$pid"
	else
		echo "Pid not found"
	fi
}

cleanup() {
  echo "🧹 Nettoyage..."
	kill_tiddlywiki
	echo "Delete $WORKDIR"
  # rm -rf "$WORKDIR"
  echo "✅ Test terminé proprement"
}
trap cleanup EXIT

echo "📁 Répertoire de travail temporaire : $WORKDIR"

# 1. 💾 Miroir bare local
mkdir -p "$(dirname "$ORIGIN")"
if [[ ! -d "$ORIGIN" ]]; then
  echo "🔧 Clonage du dépôt d'origine (bare)"
  git clone --bare https://github.com/dionisos2/tiddlygit.git "$ORIGIN"
else
  echo "🔄 Mise à jour du dépôt miroir"
  (cd "$ORIGIN" && git fetch origin)
fi

# 2. 📥 Clone de test
echo "📥 Clonage pour test"
git -C "$CLONE" pull || git clone "$ORIGIN" "$CLONE"
cd "$CLONE"
git remote set-url origin "$ORIGIN"

# 3. 🛠 Installation et serveur
echo "📦 Installation"
chmod +x installation.sh run.sh synchronize.sh
./installation.sh

echo "🚀 Lancement du serveur TiddlyGit"
./run.sh &
# attention : run.sh lance un serveur en arrière-plan, PID != $!
sleep 1  # laisse le temps initial
# attendre via check de port + attendre que serveur soit dispo
for i in {1..20}; do
  curl -fs http://localhost:7070/ && break
  sleep 1
  echo "⏳ En attente du serveur..."
done
curl -fs http://localhost:7070/ || { echo "❌ Le serveur n'a pas démarré"; exit 1; }
echo "✅ Serveur ok"

# 4. 🧪 Test de gestion de conflits

echo "🧪 Création de gestion de conflits"

cd "$CLONE"
# créer un tiddler de test
printf "\n\nbob conflict" >> Wikis/BobWiki/tiddlers/test.tid

# 1ère synchronisation (push de base)
./synchronize.sh
sleep 2
kill_tiddlywiki

# retour à état HEAD précédent
git reset --hard HEAD^

# simulateur de conflit
printf "\n\ninstance conflict" >> Wikis/BobWiki/tiddlers/test.tid

# 2e appel => doit provoquer un conflit
./synchronize.sh
sleep 2
kill_tiddlywiki

# 🕵️ Vérification du fichier créé par tiddly-merge
echo "📁 Recherche des tiddlers taggés GitConflict..."
CONFLICT_FILES=$(grep -lR "GitConflict" Wikis/BobWiki/tiddlers/) || true

if [[ -z "${CONFLICT_FILES:-}" ]]; then
  echo "❌ Aucun tiddler avec tag GitConflict trouvé — le merge driver n’a pas fonctionné"
  exit 1
fi

echo "✅ Merge driver a généré les fichiers suivants :"
echo "$CONFLICT_FILES"

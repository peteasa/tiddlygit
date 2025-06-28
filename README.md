# Introduction

A TiddlyWiki/TiddlyBob configured to work collaboratively through git.
I did it for my personal use case, and it is probably not the correct way to do it, but feel free to try it or to take some parts of it as an inspiration.
The goal is to have a button inside the Wiki that you can click to commit and push your changes and which take care of conflicts.

## Notes

The TiddlyWiki server will be closed and restarted each time you use the synchronization button. This was necessary because otherwise the Bob plugin could modify the files during the git commands, leading to data lost.

After a completed synchronization, you should reload the browser page (F5) to get the last changes loaded inside it.

If there is any problem during the synchronization, it will stop, and you will have to look inside the console what is happening with git.

Don't hesitate to create an issue if you have a question or if there is any problem.

## Merge and Conflicts

First any conflicts on these fields will simply be ignored: "modified", "created", "nouvelle-tache", "fields-to-show", "date-start", "date-start-temp", "days-count", "days-count-temp", "show-day-record".
(see tiddly-merge.py)
The goal is to avoid useless conflicts for unimportant field (in particular the field "modified")
Then, any tiddler with remaining conflicts will be duplicated (one for each version), with added link at the bottom in each one referencing the other one, they will also be tagged with the GitConflit tag.
You can then simply remove/edit these tiddlers before commiting/pushing again with the GitHub button.

Some particular tiddlers are also completely ignored, see the .gitignore file.


# Installation

Preferred way :

`git clone https://github.com/dionisos2/tiddlygit.git`
Then modify tiddlygit/.git/config to change the remote link.

or

Fork https://github.com/dionisos2/tiddlygit on GitHub
Then `git clone your_fork`

Then

```
cd tiddlygit
installation.sh
```

## Update

```
git remote add upstream https://github.com/dionisos2/tiddlygit.git
git pull upstream
update.sh
```

# Usage

## Only having to enter credential one time
### If you use SSH to connect to your depot (preferred way)

```
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa
```

### If you use you login and password to connect to your depot

```
git config --global credential.helper store
```
This will create a `~/.git-credentials` where the password is in clear (https://git-scm.com/docs/gitcredentials).

Then start the server with `run.sh` and  open http://localhost:7070/ in a WebBrowser.
(you can change the port in Wikis/BobWiki/settings/settings.json)

Then you can click the button with a GitHub icon to synchronize your work with the remote repository (you should reload the browser page after doing it to get the last modifications).

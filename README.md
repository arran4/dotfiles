# arran4 dotfiles

I have maintained a consistent dot file since I think 2004ish perhaps a bit earlier. This repo represents a complete rewrite. (I have another repo for my older dot configs which earlist commit was 2007ish.. But I had been using it via diff+ssh, rcs, svn, and finally git. But I didn't port RCS into SVN so I had lost earlier history.) --- Anyway. Enjoy. 

I have a lot of things here that was specific to a particular place and time which are probably no longer relevant, porting them to chezmoi was I guess for my own interest sake.

# Usage

I recommend you copy and paste the good stuff out into your own chezmoi config rather than just mine there is a lot of config here which is specific to me or specific to a particular situation I had been in in the past.

Using chezmoi https://www.chezmoi.io/docs/quick-start/

# Notes

I don't think it's a good idea just to apply my dot files on to your system as there are a lot of configuration options and scripts I have put in intentionally, these could go unnoticed or taken for granted (which will make switching to other systems harder.) Saying that please pick out what you like / want. I am also happy to take suggestions in the form of PR or issues.

# Tools:

| Tool | What |
| --- | --- |
| (Atuin)[https://atuin.sh/] | Command line history syncing and searching tool for zsh/bash. |
| (Chezmoi)[https://www.chezmoi.io/#considering-using-chezmoi] | Dot files syncing tool |
| Zsh | Default shell |
| Kdiff3 | Default gui diff compare |
| vimdiff | Default tui diff compare 
import git
from colorama import Fore, Style
from pprint import pprint

def get_repo_name_from_url(url: str) -> str:
    last_slash_index = url.rfind("/")
    last_suffix_index = url.rfind(".git")
    if last_suffix_index < 0:
        last_suffix_index = len(url)

    if last_slash_index < 0 or last_suffix_index <= last_slash_index:
        raise Exception("Badly formatted url {}".format(url))

    return url[last_slash_index + 1:last_suffix_index]

class Object:
    pass

def detect_changes(repo):

    diff = repo.git.diff(None, name_only=True)
    untracked_files = repo.untracked_files

    if diff or untracked_files:
        change = Object()
        change.name = get_repo_name_from_url(repo.remotes[0].config_reader.get("url"))
        change.repo = repo
        change.diff = diff
        change.untracked_files = untracked_files
        return change

repo_changes = []

def append_changes(repo):
    change = detect_changes(repo)
    if change:
        repo_changes.append(change)

root_repo = git.Repo()

for submodule in root_repo.submodules:
    repo = submodule.module()
    append_changes(repo)

append_changes(root_repo)

def is_pushed(push_info: git.remote.PushInfo) -> bool:
    valid_flags = {push_info.FAST_FORWARD, push_info.NEW_HEAD}  # UP_TO_DATE flag is intentionally skipped.
    return push_info.flags in valid_flags  # This check can require the use of & instead.

def print_files(files, color):
    for file in files:
        print(f"\t{color}{file}{Style.RESET_ALL}")

if repo_changes:

    for change in repo_changes:

        repo = change.repo

        print(f"{Fore.GREEN}{change.name}{Style.RESET_ALL} on branch {Fore.YELLOW}{repo.active_branch.name}{Style.RESET_ALL}:")

        if change.diff:
            print_files(change.diff.splitlines(), Fore.RED)

        if change.untracked_files:
            print_files(change.untracked_files, Fore.RED)

    commit_message = input("Commit message: ")

    if commit_message:

        for change in repo_changes:

            repo = change.repo
            repo.git.add(all=True)
            repo.git.commit('-m', commit_message)
            origin = repo.remote('origin')
            info = origin.push()[0]
            pprint(info)
            if is_pushed(info):
                print("Pushed.")
            else:
                print("The changes has not been pushed.")
                break

    else:

        print("Empty message. Bye.")

else:

    print("No changes to commit.")

function SetGitEncoding{
    git config --global i18n.commitencoding utf-8
    git config --global i18n.logoutputencoding utf-8
    set LESSCHARSET=utf-8
    git config --global core.quotepath false
}
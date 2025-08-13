#use polars
#use aris

export def increment []: int -> int  {
    $in + 1
    #use std/formats *
    #ls | to jsonl
}

export def pa [] {
    let s = (kind get kubeconfig)
    let git_token = (gh auth token)
    print $s
    print $git_token
}

export def security [] {
    ls
}

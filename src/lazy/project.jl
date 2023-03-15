function project(trace::LazyTrace, selection::Selection)
    project_recurse(trace.trie, selection)
end

project(trace::LazyTrace, ::EmptySelection) = trace.noise
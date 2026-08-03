function clean_local_data_folder(verbose)
% cleanup_local_data_path
%
% Remove empty folders/subfolders in local data path
%
% verbose = true/false: display removed folders (true by default)
arguments
    verbose = true
end

local_data_dir = dir(fullfile(plab.locations.local_data_path,'/**/'));

all_folders = {local_data_dir.folder};
file_folders = {local_data_dir(~[local_data_dir.isdir]).folder};

empty_folder_idx = ~arrayfun(@(x) any(contains(file_folders,x)),all_folders);
empty_folders = string(unique({local_data_dir(empty_folder_idx).folder}));

if ~isempty(empty_folders)
    [~,subfolder_sort] = sort(strlength(empty_folders),'descend');
    for curr_empty_folder = empty_folders(subfolder_sort)
        if strcmp(curr_empty_folder,plab.locations.local_data_path)
            % Keep parent folder even if empty
            continue
        end
        remove_success = rmdir(curr_empty_folder);
        if verbose
            if remove_success
                fprintf('Removed: %s\n',curr_empty_folder)
            else
                fprintf('Could not remove: %s\n',curr_empty_folder)
            end
        end
    end
end
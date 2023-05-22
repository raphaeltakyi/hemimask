%% SPM path

% adapt to your spm12 directeory path
if isempty(which('spm_spm'))
    spm_path = '/Users/sc/POOL_IRM04/IRM04/TOOLBOXES/spm12';
    addpath(spm_path);
end

%% SPM initialisations

spm('defaults', 'FMRI');
spm_get_defaults('ui.print', 'pdf');
spm_jobman('initcfg');


%% define path

% adapt to your own file structure, filenames, etc.
BIDS_ds_rep = '/Users/sc/Desktop/BRAINAGE/dataset';

subject_name = 'test01';

info_dir = fullfile(BIDS_ds_rep, 'derivative', sprintf('sub-%s', subject_name), 'info');
mkdir(info_dir);

anat_dir = fullfile(BIDS_ds_rep, 'derivative', sprintf('sub-%s', subject_name), 'anat');
mkdir(anat_dir);

anat_path = fullfile(anat_dir, sprintf('sub-%s_t1w.nii', subject_name));
copyfile(fullfile(BIDS_ds_rep, sprintf('sub-%s', subject_name), 'anat', sprintf('sub-%s_t1w.nii', subject_name)), anat_path);


%% get anat image info

anat_vol = spm_vol(anat_path);

% resolution
anat_res = spm_imatrix(anat_vol.mat);
anat_res = abs(anat_res(7:9));


%% Segmentation & normalization

normestim_batch{1}.spm.spatial.preproc.channel.vols={anat_path};
normestim_batch{1}.spm.spatial.preproc.channel.write = [0 0];

ngaus  = [1 1 2 3 4 2];

for c = 1:6
    normestim_batch{1}.spm.spatial.preproc.tissue(c).tpm = {fullfile(spm('dir'), 'tpm', sprintf('TPM.nii,%d', c))};
    normestim_batch{1}.spm.spatial.preproc.tissue(c).ngaus = ngaus(c);
    normestim_batch{1}.spm.spatial.preproc.tissue(c).native = [0 0];
    normestim_batch{1}.spm.spatial.preproc.tissue(c).warped = [0 0];
end
normestim_batch{1}.spm.spatial.preproc.warp.write = [1 1];

fprintf('Segmentation...\n');

fp = spm_figure('Create', 'Interactive', 'Interactive', 'on');
set(fp, 'Position', [0 0 300 300]);

spm_jobman('run', normestim_batch);

spm_figure('Close', fp);


%% create mask for right and left hemisphere on mni template

% intracranial volume mask
mni_tpm = fullfile(spm('dir'), 'tpm', 'mask_ICV.nii');
mni_tpm_vol = spm_vol(mni_tpm);
mni_tpm_val = spm_read_vols(mni_tpm_vol);

% define common headers for right and left masks
mni_mask_R_vol.dim = mni_tpm_vol.dim;
mni_mask_R_vol.mat = mni_tpm_vol.mat;
mni_mask_R_vol.dt = mni_tpm_vol.dt;

mni_mask_L_vol = mni_mask_R_vol;

% right mask
mni_mask_R_vol.fname = fullfile(anat_dir, 'mni_mask_R.nii');
mni_mask_R_val = mni_tpm_val;

% right hemisphere is from 0 to half first dimention (excluding middle slice)
mni_mask_R_val(ceil(mni_tpm_vol.dim(1)/2):end, :, :) = 0;

% left mask
mni_mask_L_vol.fname = fullfile(anat_dir, 'mni_mask_L.nii');
mni_mask_L_val = mni_tpm_val;

% left hemisphere is from half first dimention to end (excluding middle slice)
mni_mask_L_val(1:ceil(mni_tpm_vol.dim(1)/2), :, :) = 0;


% write masks nifti image
spm_write_vol(mni_mask_R_vol, mni_mask_R_val);
spm_write_vol(mni_mask_L_vol, mni_mask_L_val);


% apply reverse normalizations

normwrite_batch{1}.spm.spatial.normalise.write.subj.def={fullfile(anat_dir, sprintf('iy_sub-%s_t1w.nii', subject_name))};
normwrite_batch{1}.spm.spatial.normalise.write.woptions.vox = anat_res;

normwrite_batch{1}.spm.spatial.normalise.write.subj.resample={mni_mask_R_vol.fname};
spm_jobman('run', normwrite_batch);

normwrite_batch{1}.spm.spatial.normalise.write.subj.resample={mni_mask_L_vol.fname};
spm_jobman('run', normwrite_batch);



%% visual check

% Initialize spm graphic window
fspm = spm_figure('Create','Graphics','Graphics','on');
tt = annotation(fspm,'textbox',[.1 .97 .8 .025],...
    'string', subject_name,...
    'FontName','Courier',...
    'FontSize',26,...
    'FontWeight','bold',...
    'VerticalAlignment','Middle',...
    'HorizontalAlignment','Center',...
    'Linestyle','none');

spm_check_registration(anat_path, anat_path, fullfile(anat_dir, 'wmni_mask_R.nii'), fullfile(anat_dir, 'wmni_mask_L.nii'));

spm_print(fullfile(info_dir, sprintf('%s_masks.pdf', subject_name)));
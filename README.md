# Rigging
Code for running rigs

## Data collection GUIs
`plab.rig.(GUI)`: 
- `exp_control`: master start/stop controller across GUIs, must be opened first
- `timelite`: NIDAQ input/output (configured locally for each rig in `plab.local_rig.timelite_config`)
- `bonsai_server`: server to listen for and start Bonsai workflows
- `mousecam`: mouse camera
- `widefield`: widefield camera (must be opened before mousecam if on same computer)


## Create/find path locations
`plab.locations.(location)`
- `server_data_path`: server location
- ports/local workflow/github: used in rigging code

`plab.locations.make_server_filename(animal,rec_day,rec_time,filepart1,...,filepartN)`: construct lab filename

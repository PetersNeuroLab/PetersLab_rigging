# Rigging
Code for running rigs

## Data collection GUIs
`plab.rig.(GUI)`: 
- `exp_control`: master start/stop controller across GUIs, must be opened first
- `timelite`: NIDAQ input/output (configured locally for each rig in `plab.local_rig.timelite_config`)
- `bonsai_server`: server to listen for and start Bonsai workflows
- `mousecam`: mouse camera
- `widefield`: widefield camera (must be opened before mousecam if on same computer)

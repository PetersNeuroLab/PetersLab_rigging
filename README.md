# Rigging
Code for running rigs

## Data collection GUIs
`plab.rig.(GUI)`: 
- `exp_control`: master start/stop controller across GUIs, must be opened first
- `timelite`: NIDAQ input/output (configured locally for each rig in `plab.local_rig.timelite_config`)
  - Requires:
    - Data acquisition toolbox
- `bonsai_server`: server to listen for and start Bonsai workflows
- `mousecam`: mouse camera
- `widefield`: widefield camera
  - Requires:
    - Matlab >r2023a
    - [DCAM-API](https://www.hamamatsu.com/eu/en/product/cameras/software/driver-software/dcam-api-for-windows.html)
    - [DCAM-API Matlab plugin](https://dcam-api.com/third-party-plugins/)
  - Must be opened before mousecam if on same computer

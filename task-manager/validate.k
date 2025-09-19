import file
import yaml

# Import the Taskfile schema
import schemas.taskfile as taskfile

# Read and validate the Taskfile
taskfile_data = yaml.decode(file.read("Taskfile.yml"))
validated_taskfile: taskfile.Taskfile = taskfile_data
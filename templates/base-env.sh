#!/bin/bash

${CONDA_DIR}/bin/conda info --envs | grep "^${ENV}"
if [ $? -ne 0 ] ; then
  ${CONDA_DIR}/bin/conda create -n $ENV python=#{python} -y -q
  if [ $? -ne 0 ] ; then
     exit 2
  fi
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade pip

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade requests
if [ $? -ne 0 ] ; then
   exit 3
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install tensorflow-serving-api==#{node['tensorflow']['serving']["version"]}
if [ $? -ne 0 ] ; then
  exit 4
fi

if [ "#{python}" == "2.7" ] ; then
    # See HOPSWORKS-870 for an explanation about this line
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install ipykernel==#{node['python2']['ipykernel_version']} ipython==#{node['python2']['ipython_version']} jupyter_console==#{node['python2']['jupyter_console_version']} hops-ipython-sql
    if [ $? -ne 0 ] ; then
      exit 6
    fi
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install matplotlib==#{node['matplotlib']['python2']['version']}
    if [ $? -ne 0 ] ; then
      exit 7
    fi
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install nvidia-ml-py==#{node['conda']['nvidia-ml-py']['version']}
    if [ $? -ne 0 ] ; then
       exit 8
    fi
else
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade ipykernel hops-ipython-sql
    if [ $? -ne 0 ] ; then
      exit 6
    fi
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade matplotlib
    if [ $? -ne 0 ] ; then
      exit 7
    fi
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install nvidia-ml-py3==#{node['conda']['nvidia-ml-py']['version']}
    if [ $? -ne 0 ] ; then
      exit 8
    fi
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade hopsfacets
if [ $? -ne 0 ] ; then
   exit 10
fi

# https://github.com/tensorflow/tensorboard/tree/master/tensorboard/plugins/interactive_inference
# pip install witwidget
# jupyter nbextension install --py --symlink --sys-prefix witwidget
# jupyter nbextension enable --py --sys-prefix witwidget
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade witwidget
if [ $? -ne 0 ] ; then
   exit 11
fi

# Takes on the value "" for CPU machines, "-gpu" for Nvidia GPU machines, "-rocm" for ROCm GPU machines
TENSORFLOW_LIBRARY_SUFFIX=
if [ -f /usr/local/cuda/version.txt ]  ; then
  nvidia-smi -L | grep -i gpu
  if [ $? -eq 0 ] ; then
    TENSORFLOW_LIBRARY_SUFFIX="-gpu"
  fi
# If system is setup for rocm already or we are installing it
else
  export ROCM=#{node['rocm']['install']}
  if [ -f /opt/rocm/bin/rocminfo ] || [$ROCM == "true"]  ; then
    TENSORFLOW_LIBRARY_SUFFIX="-rocm"
  fi
fi

# Uninstall tensorflow pulled in by tensorflow-serving-api to prepare for the actual TF installation
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip uninstall tensorflow
if [ $? -ne 0 ] ; then
    echo "Problem uninstalling tensorflow"
fi
# Uninstall tensorflow-estimator pulled in by tensorflow-serving-api to prepare for the actual TF installation
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip uninstall tensorflow-estimator
if [ $? -ne 0 ] ; then
    echo "Problem uninstalling tensorflow-estimator"
fi
# Uninstall tensorboard pulled in by tensorflow-serving-api to prepare for the actual TF installation
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip uninstall tensorboard
if [ $? -ne 0 ] ; then
    echo "Problem uninstalling tensorboard"
fi

 Install a custom build of tensorflow with this line.
if [ $CUSTOM_TF -eq 1 ] ; then
  yes | #{node['conda']['base_dir']}/envs/${ENV}/bin/pip install --upgrade #{node['tensorflow']['custom_url']}/tensorflow${TENSORFLOW_LIBRARY_SUFFIX}-#{node['tensorflow']['version']}-cp${PY}-cp${PY}mu-manylinux1_x86_64.whl --force-reinstall else
  if [ $TENSORFLOW_LIBRARY_SUFFIX == "-rocm" ] ; then
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install tensorflow${TENSORFLOW_LIBRARY_SUFFIX}==#{node['tensorflow']['rocm']['version']}  --upgrade --force-reinstall
  else
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install tensorflow${TENSORFLOW_LIBRARY_SUFFIX}==#{node['tensorflow']['version']}  --upgrade --force-reinstall
  fi
fi
if [ $? -ne 0 ] ; then
   exit 12
fi

export HOPS_UTIL_PY_VERSION=#{node['conda']['hops-util-py']['version']}
export HOPS_UTIL_PY_BRANCH=#{node['conda']['hops-util-py']['branch']}
export HOPS_UTIL_PY_REPO=#{node['conda']['hops-util-py']['repo']}
export HOPS_UTIL_PY_INSTALL_MODE=#{node['conda']['hops-util-py']['install-mode']}
if [ $HOPS_UTIL_PY_INSTALL_MODE == "git" ] ; then
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install git+https://github.com/${HOPS_UTIL_PY_REPO}/hops-util-py@$HOPS_UTIL_PY_BRANCH
else
    yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install hops==$HOPS_UTIL_PY_VERSION
fi
if [ $? -ne 0 ] ; then
   exit 13
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade pyjks
if [ $? -ne 0 ] ; then
   exit 14
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade confluent-kafka
if [ $? -ne 0 ] ; then
   exit 15
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade hops-petastorm
if [ $? -ne 0 ] ; then
   exit 16
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade opencv-python
if [ $? -ne 0 ] ; then
   exit 17
fi

export PYTORCH_CHANNEL=#{node['conda']['channels']['pytorch']}
if [ "${PYTORCH_CHANNEL}" == "" ] ; then
  PYTORCH_CHANNEL="pytorch"
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install maggy==#{node['maggy']['version']}
if [ $? -ne 0 ] ; then
  exit 18
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade tqdm
if [ $? -ne 0 ] ; then
   exit 19
fi


if [ $TENSORFLOW_LIBRARY_SUFFIX == "-gpu" ] ; then
  if [ "#{python}" == "2.7" ] ; then
    ${CONDA_DIR}/bin/conda install -y -n ${ENV} -c ${PYTORCH_CHANNEL} pytorch=#{node['pytorch']['version']}=#{node["pytorch"]["python2"]["build"]} torchvision=#{node['torchvision']['version']} cudatoolkit=#{node['cudatoolkit']['version']}
    if [ $? -ne 0 ] ; then
      exit 20
    fi
  else
    ${CONDA_DIR}/bin/conda install -y -n ${ENV} -c ${PYTORCH_CHANNEL} pytorch=#{node['pytorch']['version']}=#{node["pytorch"]["python3"]["build"]} torchvision=#{node['torchvision']['version']} cudatoolkit=#{node['cudatoolkit']['version']}
    if [ $? -ne 0 ] ; then
      exit 21
    fi
  fi
  ${CONDA_DIR}/bin/conda remove -y -n ${ENV} cudatoolkit=#{node['cudatoolkit']['version']} --force
  if [ $? -ne 0 ] ; then
    exit 22
  fi
else
  ${CONDA_DIR}/bin/conda install -y -n ${ENV} -c ${PYTORCH_CHANNEL} pytorch-cpu=#{node['pytorch']['version']} torchvision-cpu=#{node['torchvision']['version']}
  if [ $? -ne 0 ] ; then
    exit 23
  fi
fi

# This is a temporary fix for pytorch 1.0.1 https://github.com/pytorch/pytorch/issues/16775
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install typing
if [ $? -ne 0 ] ; then
   exit 24
fi

# for sklearn serving

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade Flask
if [ $? -ne 0 ] ; then
   exit 25
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade scikit-learn
if [ $? -ne 0 ] ; then
   exit 26
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade avro
if [ $? -ne 0 ] ; then
   exit 27
fi

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade seaborn
if [ $? -ne 0 ] ; then
   exit 28
fi

${CONDA_DIR}/envs/${ENV}/bin/pip install pydoop==#{node['pydoop']['version']}
if [ $? -ne 0 ] ; then
   exit 29
fi

# Install Jupyter packages
set -e 
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --no-cache-dir --upgrade jupyter
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --no-cache-dir --upgrade hdfscontents urllib3 requests pandas

# Install packages to allow users to manage their jupyter extensions
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --no-cache-dir --upgrade jupyter_contrib_nbextensions jupyter_nbextensions_configurator

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --upgrade ./hdijupyterutils ./autovizwidget ./sparkmagic

# THIS IS A WORKAROUND FOR UNTIL NOTEBOOK GETS FIXED UPSTREAM TO WORK WITH THE NEW VERSION OF TORNADO
# SEE: https://logicalclocks.atlassian.net/browse/HOPSWORKS-977

yes | ${CONDA_DIR}/envs/${ENV}/bin/pip uninstall tornado
yes | ${CONDA_DIR}/envs/${ENV}/bin/pip install --no-cache-dir tornado==5.1.1

# Enable kernels
cd ${CONDA_DIR}/envs/${ENV}/lib/python#{python}/site-packages

${CONDA_DIR}/envs/${ENV}/bin/jupyter-kernelspec install sparkmagic/kernels/sparkkernel --sys-prefix
${CONDA_DIR}/envs/${ENV}/bin/jupyter-kernelspec install sparkmagic/kernels/pysparkkernel --sys-prefix
${CONDA_DIR}/envs/${ENV}/bin/jupyter-kernelspec install sparkmagic/kernels/pyspark3kernel --sys-prefix
${CONDA_DIR}/envs/${ENV}/bin/jupyter-kernelspec install sparkmagic/kernels/sparkrkernel --sys-prefix

# Enable extensions
${CONDA_DIR}/envs/${ENV}/bin/jupyter nbextension enable --py --sys-prefix widgetsnbextension

${CONDA_DIR}/envs/${ENV}/bin/jupyter contrib nbextension install --sys-prefix
${CONDA_DIR}/envs/${ENV}/bin/jupyter serverextension enable jupyter_nbextensions_configurator --sys-prefix
// Helpers shared by the Jenkinsfiles under scripts/.  Each Jenkins job holds its pipeline script inline, and
// push-jobs.py writes that script as this file followed by the job's Jenkinsfile.  The Jenkinsfile calls the
// helpers as lqx.<name>(...) inside a script block.
import groovy.transform.Field

@Field final String REPO_URL = 'https://github.com/damentz/liquorix-package.git'
@Field final String KEY_ID = 'C5ADB4F3FEBBCE27A3E54D7D9AE4078033F8024D'
// Filled in by push-jobs.py: the job's Jenkinsfile, and a hash of the sources its script was written from
@Field final String SOURCE = ''
@Field final String SOURCE_HASH = ''

// Clone a tag or branch (empty: the default branch) and return its commit
def clonePackage(String ref = '') {
    sh "rm -rf liquorix-package && git clone -q --depth=1 ${ref ? "--branch '${ref}'" : ''} '${REPO_URL}' liquorix-package"
    checkCurrent()
    return sh(returnStdout: true, script: 'git -C liquorix-package rev-parse HEAD').trim()
}

// Stop when the job's script wasn't written from the pipeline sources in the tree being built
def checkCurrent() {
    def hash = sh(returnStdout: true, script: "cat liquorix-package/scripts/jenkins/lqx.groovy 'liquorix-package/${SOURCE}' | sha256sum | cut -d' ' -f1").trim()
    if (hash == SOURCE_HASH) {
        return
    }
    def message = "The job script doesn't match ${SOURCE} in this tree, run scripts/jenkins/push-jobs.py"
    // Test runs may carry pipeline changes that aren't pushed yet
    if (params.SKIP_PUBLISH || params.DRY_RUN) {
        echo "WARNING: ${message}"
    } else {
        error message
    }
}

// Clone liquorix-package at a fixed commit so every node builds the same tree
def checkoutPackage(String sha) {
    sh """
        rm -rf liquorix-package
        git init -q liquorix-package
        git -C liquorix-package fetch -q --depth=1 '${REPO_URL}' '${sha}'
        git -C liquorix-package checkout -q FETCH_HEAD
    """
}

def importKey() {
    withCredentials([file(credentialsId: '6e773de0-6613-45ed-ae4c-7f337540da8d', variable: 'KEY_FILE')]) {
        sh """
            gpg --import "\$KEY_FILE"
            echo 'default-key ${KEY_ID}' >> ~/.gnupg/gpg.conf
        """
    }
}

// Read a variable from scripts/<distro>/env.sh in the clone
def envVar(String distro, String name) {
    return sh(returnStdout: true, script: "bash -c 'source liquorix-package/scripts/${distro}/env.sh && echo \"\${${name}}\"'").trim()
}

// Tag pushes build the tag, manual runs build the branch or the default branch.  Returns the commit.
def prepare(String distro, String branch = '') {
    def tag = env.ref ? env.ref.replaceFirst('^refs/tags/', '') : ''
    def commit = clonePackage(tag ?: branch)
    def version = envVar(distro, 'version_package')
    if (tag && tag != version) {
        error "Tag ${tag} doesn't match changelog version ${version}"
    }
    currentBuild.displayName = "#${env.BUILD_NUMBER} - v${version}.${params.BUILD}"
    return commit
}

// EC2 hosts are destroyed after each run, so no workspace cleanup
def buildNode(String commit, Closure body) {
    node('ec2-build') {
        checkoutPackage(commit)
        importKey()
        body()
    }
}

def makeBinary(String distro, String release) {
    sh """
        make -C liquorix-package DISTRO=${distro} RELEASE='${release}' bootstrap-image
        make -C liquorix-package DISTRO=${distro} RELEASE='${release}' BUILD="\$BUILD" build-binary
    """
}

// "Restart from Stage" skips the stages before it and the variables they set, but copies their stashes
// (preserveStashes), so stages hand later ones what they need through stashes.  These need a workspace.
def saveState(Map state) {
    def text = ''
    for (key in state.keySet()) {
        text += "${key}=${state[key]}\n"
    }
    dir('state') {
        writeFile file: 'state', text: text
        stash name: 'state', includes: 'state'
    }
}

// Returns the map saveState() stashed, values as strings
def loadState() {
    def state = [:]
    dir('state') {
        unstash 'state'
        for (line in readFile('state').split('\n')) {
            def kv = line.split('=', 2)
            state[kv[0]] = kv.size() > 1 ? kv[1] : ''
        }
        deleteDir()
    }
    return state
}

// Mark a piece of work finished so a restarted run can skip it
def markDone(String kind, String name) {
    dir('done') {
        writeFile file: "${kind}-${name}", text: ''
        stash name: "done-${kind}-${name}", includes: "${kind}-${name}"
    }
}

// The names whose work markDone() recorded, in this run or the one it restarted from
def done(String kind, List names) {
    def found = []
    dir('done') {
        for (name in names) {
            try {
                unstash "done-${kind}-${name}"
                found << name
            } catch (hudson.AbortException e) {
                // Not finished yet
            }
        }
        deleteDir()
    }
    return found
}

def email() {
    emailext to: 'steven@liquorix.net',
             subject: '$PROJECT_NAME - Build # $BUILD_NUMBER - $BUILD_STATUS!',
             body: 'Check console output at $BUILD_URL to view the results.',
             attachLog: true,
             compressLog: true
}

// The Jenkinsfile that follows calls the helpers above through this
def lqx = this

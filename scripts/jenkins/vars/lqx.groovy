// Helpers shared by the Jenkinsfiles under scripts/.  Each one loads them from its own checkout with
//   library identifier: 'lqx@scm', changelog: false, retriever: legacySCM(scm: scm, libraryPath: 'scripts/jenkins')
// and calls lqx.<name>(...) inside a script block.  With the changelog on, Jenkins polls this checkout too,
// and a job with a push trigger (Arch) would then build on every push to this repository.
import groovy.transform.Field

@Field final String REPO_URL = 'https://github.com/damentz/liquorix-package.git'
@Field final String KEY_ID = 'C5ADB4F3FEBBCE27A3E54D7D9AE4078033F8024D'

// Clone a tag or branch (empty: the default branch) and return its commit
def clonePackage(String ref = '') {
    sh "rm -rf liquorix-package && git clone -q --depth=1 ${ref ? "--branch '${ref}'" : ''} '${REPO_URL}' liquorix-package"
    return sh(returnStdout: true, script: 'git -C liquorix-package rev-parse HEAD').trim()
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

def email() {
    emailext to: 'steven@liquorix.net',
             subject: '$PROJECT_NAME - Build # $BUILD_NUMBER - $BUILD_STATUS!',
             body: 'Check console output at $BUILD_URL to view the results.',
             attachLog: true,
             compressLog: true
}

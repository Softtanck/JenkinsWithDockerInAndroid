#!/usr/bin/env groovy

//This JenkinsFile is based on a declarative format
//https://jenkins.io/doc/book/pipeline/#declarative-versus-scripted-pipeline-syntax
def CSD_DEPLOY_BRANCH = 'development'
// Do not add the `def` for these fields
XXPROJECT_ID = 974
GITLAB_SERVER_URL = 'http://gitlab.com'// Or your server

pipeline {
    // 默认代理用主机,意味着用Jenkins主机来运行一下块
    agent any
    options {
        // 配置当前branch不支持同时构建,为了避免资源竞争,当一个新的commit到来,会进入排队如果之前的构建还在进行
        disableConcurrentBuilds()
        // 链接到Gitlab的服务器,用于访问Gitlab一些API
        gitLabConnection('Jenkins_CI_CD')
    }
    environment {
        // 配置缓存路径在主机
        GRADLE_CACHE = '/tmp/gradle-user-cache'
    }
    stages {
        // 初始化阶段
        stage('Setup') {
            steps {
                // 将初始化阶段修改到这次commit即Gitlab会展示对应的UI
                gitlabCommitStatus(name: 'Setup') {
                    // 通过SLACK工具推送一个通知
                    notifySlack('STARTED')
                    echo "Setup Stage Starting. Depending on the Docker cache this may take a few " +
                            "seconds to a couple of minutes."
                    echo "${env.BRANCH_NAME} is the branch.  Subsequent steps may not run on branches that are not ${CSD_DEPLOY_BRANCH}."
                    script {
                        cacheFileExist = sh(script: "[ -d ${GRADLE_CACHE} ]  && echo 'true' || echo 'false' ", returnStdout: true).trim()
                        echo 'Current cacheFile is exist : ' + cacheFileExist
                        // Make dir if not exist
                        if (cacheFileExist == 'false') sh "mkdir ${GRADLE_CACHE}/ || true"
                    }
                }
            }
        }

        // 构建阶段
        stage('Build') {
            agent {
                dockerfile {
                    // 构建的时候指定一个DockerFile,该DockerFile有Android的构建环境
                    filename 'Dockerfile'
                    // https://github.com/gradle/gradle/issues/851
                    args '-v $GRADLE_CACHE/.gradle:$HOME/.gradle --net=host'
                }
            }

            steps {
                gitlabCommitStatus(name: 'Build') {

                    script {
                        echo "Build Stage Starting"
                        echo "Building all types (debug, release, etc.) with lint checking"
                        getGitAuthor()

                        if (env.BRANCH_NAME == CSD_DEPLOY_BRANCH) {

                            // TODO : Do some checks on your style

                            // https://docs.gradle.org/current/userguide/gradle_daemon.html
                            sh 'chmod +x gradlew'
                            // Try with the all build types.
                            sh "./gradlew build"
                        } else {
                            // https://docs.gradle.org/current/userguide/gradle_daemon.html
                            sh 'chmod +x gradlew'
                            // Try with the production build type.
                            sh "./gradlew compileReleaseJavaWithJavac"
                        }
                    }
                }

                /* Comment out the inner cache rsync logic
                gitlabCommitStatus(name: 'Sync Gradle Cache') {
                    script {
                        if (env.BRANCH_NAME != CSD_DEPLOY_BRANCH) {
                            // TODO : The max cache file should be added.
                            echo 'Write updates to the Gradle cache back to the host'
                            // Write updates to the Gradle cache back to the host

                            // -W, --whole-file:
                            // With this option rsync's delta-transfer algorithm is not used and the whole file is sent as-is instead.
                            // The transfer may be faster if this option is used when the bandwidth between the source and
                            // destination machines is higher than the bandwidth to disk (especially when the lqdiskrq is actually a networked filesystem).
                            // This is the default when both the source and destination are specified as local paths.
                            sh "rsync -auW ${HOME}/.gradle/caches ${HOME}/.gradle/wrapper ${GRADLE_CACHE}/ || true"
                        } else {
                            echo 'Not on the Deploy branch , Skip write updates to the Gradle cache back to the host'
                        }
                    }
                }*/

                script {
                    // Only the development branch can be triggered
                    if (env.BRANCH_NAME == CSD_DEPLOY_BRANCH) {
                        gitlabCommitStatus(name: 'Signature') {
                            // signing the apks with the platform key
                            signAndroidApks(
                                    keyStoreId: "platform",
                                    keyAlias: "platform",
                                    apksToSign: "**/*.apk",
                                    archiveSignedApks: false,
                                    skipZipalign: true
                            )
                        }

                        gitlabCommitStatus(name: 'Deploy') {
                            script {
                                echo "Debug finding apks"
                                // debug statement to show the signed apk's
                                sh 'find . -name "*.apk"'

                                // TODO : Deploy your apk to other place

                                //Specific deployment to Production environment
                                //echo "Deploying to Production environment"
                                //sh './gradlew app:publish -DbuildType=proCN'
                            }
                        }
                    } else {
                        echo 'Current branch of the build not on the development branch, Skip the next steps!'
                    }
                }
            }
            // This post working on the docker. not on the jenkins of local
            post {
                // The workspace should be cleaned if the build is failure.
                failure {
                    // notFailBuild : if clean failed that not tell Jenkins failed.
                    cleanWs notFailBuild: true
                }
                // The APKs should be deleted when the server is successfully built.
                success {
                    script {
                        // Only the development branch can be deleted these APKs.
                        if (env.BRANCH_NAME == CSD_DEPLOY_BRANCH) {
                            cleanWs notFailBuild: true, patterns: [[pattern: '**/*.apk', type: 'INCLUDE']]
                        }
                    }
                }
            }
        }
    }

    post {
        always { deleteDir() }
        failure {
            addCommentToGitLabMR("\\:negative_squared_cross_mark\\: Jenkins Build \\`FAILURE\\` <br /><br /> Results available at:[[#${env.BUILD_NUMBER} ${env.JOB_NAME}](${env.BUILD_URL})]")
            notifySlack('FAILED')
        }
        success {
            addCommentToGitLabMR("\\:white_check_mark\\: Jenkins Build \\`SUCCESS\\` <br /><br /> Results available at:[[#${env.BUILD_NUMBER} ${env.JOB_NAME}](${env.BUILD_URL})]")
            notifySlack('SUCCESS')
        }
        unstable { notifySlack('UNSTABLE') }
        changed { notifySlack('CHANGED') }
    }
}

def addCommentToGitLabMR(String commentContent) {
    branchHasMRID = sh(script: "curl --header \"PRIVATE-TOKEN: ${env.gitTagPush}\" ${GITLAB_SERVER_URL}/api/v4/projects/${XXPROJECT_ID}/merge_requests?source_branch=${env.BRANCH_NAME} | grep -o 'iid\":[^,]*' | head -n 1 | cut -b 6-", returnStdout: true).trim()
    echo 'Current Branch has MR id : ' + branchHasMRID
    if (branchHasMRID == '') {
        echo "The id of MR doesn't exist on the gitlab. skip the comment on MR"
    } else {
        // TODO : Should be handled on first time.
        TheMRState = sh(script: "curl --header \"PRIVATE-TOKEN: ${env.gitTagPush}\" ${GITLAB_SERVER_URL}/api/v4/projects/${XXPROJECT_ID}/merge_requests?source_branch=${env.BRANCH_NAME} | grep -o 'state\":[^,]*' | head -n 1 | cut -b 9-14", returnStdout: true).trim()
        echo 'Current MR state is : ' + TheMRState
        if (TheMRState == 'opened') {
            sh "curl -d \"id=${XXPROJECT_ID}&merge_request_iid=${branchHasMRID}&body=${commentContent}\" --header \"PRIVATE-TOKEN: ${env.gitTagPush}\" ${GITLAB_SERVER_URL}/api/v4//projects/${XXPROJECT_ID}/merge_requests/${branchHasMRID}/notes"
        } else {
            echo 'The MR not is opened, skip the comment on MR'
        }
    }
}

def pushTag(String gitTagName, String gitTagContent) {
    sh "curl -d \"id=${XXPROJECT_ID}&tag_name=${gitTagName}&ref=development&release_description=${gitTagContent}\" --header \"PRIVATE-TOKEN: ${env.gitTagPush}\" ${GITLAB_SERVER_URL}/api/v4/projects/${XXPROJECT_ID}/repository/tags"
}

//Helper methods
//TODO Probably can extract this into a JenkinsFile shared library
def getGitAuthor() {
    def commitSHA = sh(returnStdout: true, script: 'git rev-parse HEAD')
    author = sh(returnStdout: true, script: "git --no-pager show -s --format='%an' ${commitSHA}").trim()
    echo "Commit author: " + author
}

def notifySlack(String buildStatus = 'STARTED') {
    // Build status of null means success.
    buildStatus = buildStatus ?: 'SUCCESS'

    def color
    if (buildStatus == 'STARTED') {
        color = '#D4DADF'
    } else if (buildStatus == 'SUCCESS') {
        color = 'good'
    } else if (buildStatus == 'UNSTABLE' || buildStatus == 'CHANGED') {
        color = 'warning'
    } else {
        color = 'danger'
    }

    def msg = "${buildStatus}: `${env.JOB_NAME}` #${env.BUILD_NUMBER}:\n${env.BUILD_URL}"

    slackSend(color: color, message: msg)
}

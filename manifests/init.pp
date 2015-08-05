# == Class: gitlab_ci_multi_runner
#
# Install gitlab CI multi runner.
#
# === Parameters
#
# [*user*]
#   Name of the gitlab CI multi-runner user.
#   Default: gitlab_ci_multi_runner
#
# [*version*]
#   Gitlab CI multi-runner ackage version to install.
#   Default: 0.4.2-1 on rhel5 and rhel6-like and 'installed' on others.
#
# === Examples
#
#  class {'gitlab_ci_multi_runner': }
#
#  include '::gitlab_ci_multi_runner'
#
# Configuration can be done using Hiera.
class gitlab_ci_multi_runner (
    $user = 'gitlab_ci_multi_runner',
    $version = $::osfamily ? {
        'redhat' => $::lsbmajdistrelease ? {
            '/5|6/' => '0.4.2.1',
            default => 'installed',
        }
        'debian' => 'installed',
        default  => 'There is no spoon',
    },
) {
    $package_manager = $::osfamily ? {
        'redhat' => 'rpm',
        'debian' => 'apt',
        default  => 'unknown',
    }

    if $package_manager == 'unknown' {
        fail("Target Operating system (${::operatingsystem}) not supported")
    } elsif $package_manager == 'apt' {
        warning("${::operatingsystem} support is still in Beta - please report any issues to the main repository at https://github.com/frankiethekneeman/puppet-gitlab-ci-multi-runner/issues")
    }

    # Get the file created by the "repo adding" step.
    $repoLocation = $package_manager ? {
        'rpm'   => '/etc/yum.repos.d/runner_gitlab-ci-multi-runner.repo',
        'apt'   => '/etc/apt/sources.list.d/runner_gitlab-ci-multi-runner.list',
        default => '/var',
        # Choose a file that will definitely be there so that we don't
        # have to worry about it running in the case of an unknown
        # package_manager type.
    }

    # Ensure the gitlab_ci_multi_runner user exists.
    # TODO:  Investigate if this is necessary - the install script may handle this.
    user { $user:
        ensure     => 'present',
        managehome => true,
    } ->
    # Add The repository to yum/apt-get
    exec { 'Add Repository':
        command  => "curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-ci-multi-runner/script.${package_manager}.sh | bash",
        user     => 'root',
        provider => 'shell',
        creates  => $repoLocation,
    } ->
    # Install the package after the repo has been added.
    package { 'gitlab-ci-multi-runner':
        ensure => $version
    } ->
    exec {'Ensure Service':
        command  => "gitlab-ci-multi-runner install --user $user",
        user     => 'root',
        provider => 'shell',
        creates  => '/etc/init.d/gitlab-ci-multi-runner'
    } ->
    # Ensure that the service is running at all times.
    service { 'gitlab-ci-multi-runner':
        ensure => 'running',
    }

    if $package_manager == 'rpm' {
        exec { 'Yum Exclude Line':
            command  => 'echo exclude= >> /etc/yum.conf',
            onlyif   => "! grep '^exclude=' /etc/yum.conf",
            user     => 'root',
            provider => 'shell',
            require  => Exec['Ensure Service']
        } ->
        exec { 'Yum Exclude gitlab-ci-multi-runner':
            command  => "sed -i 's/^exclude=.*$/& gitlab-ci-multi-runner/' /etc/yum.conf",
            onlyif   => "! grep '^exclude=.*gitlab-ci-multi-runner' /etc/yum.conf",
            user     => 'root',
            provider => 'shell',
        }
    }
}

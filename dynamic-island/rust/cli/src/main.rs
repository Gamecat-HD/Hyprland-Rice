//! Front of the `dynamic-island` command.
//!
//! Only what is ported runs here. Everything else, every help text and every
//! input we do not understand goes to the Python CLI unchanged, so its behaviour
//! stays what it was.

mod plugin;

use std::ffi::OsString;
use std::os::unix::process::CommandExt;
use std::path::PathBuf;
use std::process::Command;

use clap::Parser;
use di_common::paths;

/// The Python CLI: where the variable points to, next to this binary, or in the config.
fn python_cli() -> PathBuf {
    if let Some(cli) = std::env::var_os("DYNAMIC_ISLAND_PYTHON_CLI") {
        return cli.into();
    }
    let sibling = std::env::current_exe()
        .ok()
        .map(|exe| exe.with_file_name("dynamic-island"));
    sibling
        .filter(|cli| cli.is_file())
        .unwrap_or_else(|| paths::c_config_dir().join("bin/dynamic-island"))
}

fn run_python(args: &[OsString]) -> ! {
    let cli = python_cli();
    let error = Command::new(&cli).arg0("dynamic-island").args(args).exec();
    eprintln!("dynamic-island: {} startet nicht: {error}", cli.display());
    std::process::exit(127);
}

fn main() {
    // A closed pipe (`dynamic-island plugin list | head`) ends us quietly.
    // SAFETY: called before any other thread exists, SIG_DFL needs no handler.
    unsafe {
        libc::signal(libc::SIGPIPE, libc::SIG_DFL);
    }

    let args: Vec<OsString> = std::env::args_os().skip(1).collect();
    if args.first().is_some_and(|a| a == "plugin")
        && let Ok(cli) = plugin::Cli::try_parse_from(
            std::iter::once(OsString::from("plugin")).chain(args[1..].iter().cloned()),
        )
        && !cli.action.uses_tilde_user()
    {
        std::process::exit(plugin::run(&cli.action));
    }
    run_python(&args);
}

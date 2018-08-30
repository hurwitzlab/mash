extern crate run_mash;

use std::process;

fn main() {
    let config = run_mash::get_args().expect("Could not get arguments");

    if let Err(e) = run_mash::run(config) {
        println!("Error: {}", e);
        process::exit(1);
    }
}

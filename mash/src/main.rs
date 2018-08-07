extern crate mash;

use std::process;

fn main() {
    let config = mash::get_args();
    println!("{:?}", config);

    if let Err(e) = mash::run(config) {
        println!("Error: {}", e);
        process::exit(1);
    }
}

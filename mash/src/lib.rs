extern crate clap;

use clap::{App, Arg};
use std::error::Error;
use std::fs::DirBuilder;
use std::{env, fmt, fs, io, path::PathBuf};

#[derive(Debug)]
pub struct Config {
    alias_file: Option<String>,
    distance: u32,
    euc_dist_percent: Option<String>,
    num_threads: u32,
    out_dir: Option<String>,
    query: String,
}

#[derive(Debug)]
struct MyError {
    details: String,
}

impl MyError {
    fn new(msg: &str) -> MyError {
        MyError {
            details: msg.to_string(),
        }
    }
}

impl fmt::Display for MyError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.details)
    }
}

impl Error for MyError {
    fn description(&self) -> &str {
        &self.details
    }
}

// --------------------------------------------------
pub fn get_args() -> Config {
    let matches = App::new("Mash All vs All")
        .version("0.1.0")
        .author("Ken Youens-Clark <kyclark@email.arizona.edu")
        .about("Run Mash all-vs-all")
        .arg(
            Arg::with_name("query")
                .short("q")
                .long("query")
                .value_name("FILE_OR_DIR")
                .help("File or input directory")
                .required(true),
        )
        .arg(
            Arg::with_name("out_dir")
                .short("o")
                .long("out_dir")
                .value_name("DIR")
                .help("Output directory"),
        )
        .arg(
            Arg::with_name("alias")
                .short("a")
                .long("alias")
                .value_name("FILE")
                .help("Aliases for sample names"),
        )
        .arg(
            Arg::with_name("euc_dist_percent")
                .short("e")
                .long("euc_dist_percent")
                .value_name("INT")
                .default_value("0.1")
                .help("Euclidean distance percentage"),
        )
        .arg(
            Arg::with_name("sample_distance")
                .short("d")
                .long("sample_distance")
                .value_name("INT")
                .default_value("1000")
                .help("Min. distance to determine \"near\" samples"),
        )
        .arg(
            Arg::with_name("num_threads")
                .short("t")
                .long("num_threads")
                .value_name("INT")
                .default_value("12")
                .help("Number of threads"),
        )
        .get_matches();

    let query = String::from(matches.value_of("query").unwrap());

    let out_dir = match matches.value_of("out_dir") {
        Some(x) => Some(String::from(x)),
        _ => None,
    };

    let alias = match matches.value_of("alias") {
        Some(x) => Some(String::from(x)),
        _ => None,
    };

    let distance: u32 = match matches.value_of("sample_distance") {
        Some(x) => match x.trim().parse() {
            Ok(n) if n > 0 => n,
            _ => 0,
        },
        _ => 0,
    };

    let num_threads: u32 = match matches.value_of("num_threads") {
        Some(x) => match x.trim().parse() {
            Ok(n) if n > 0 && n < 64 => n,
            _ => 0,
        },
        _ => 0,
    };

    let euc_dist_percent = match matches.value_of("euc_dist_percent") {
        Some(x) => Some(String::from(x)),
        _ => None,
    };

    Config {
        alias_file: alias,
        distance: distance,
        euc_dist_percent: euc_dist_percent,
        num_threads: num_threads,
        out_dir: out_dir,
        query: query,
    }
}

// --------------------------------------------------
pub fn run(config: Config) -> Result<(), Box<Error>> {
    let out_dir = setup_out_dir(&config.out_dir)?;
    println!("out_dir = {}", out_dir.display());

    let files = find_files(&config.query)?;

    let res = sketch_files(&files)?;

    println!("files = {:?}", files);

    Ok(())
}

// --------------------------------------------------
fn find_files(path: &str) -> Result<Vec<PathBuf>, io::Error> {
    let meta = fs::metadata(path)?;

    if meta.is_file() {
        Ok(vec![PathBuf::from(path)])
    } else if meta.is_dir() {
        fs::read_dir(path)?
            .into_iter()
            .map(|x| x.map(|entry| entry.path()))
            .collect()
    } else {
        Ok(vec![])
    }
}

// --------------------------------------------------
fn setup_out_dir(dir: &Option<String>) -> Result<PathBuf, Box<Error>> {
    let dir = match dir {
        Some(dirname) => PathBuf::from(dirname),
        None => {
            let cwd = env::current_dir()?;
            cwd.join(PathBuf::from("mash-out"))
        }
    };

    if !dir.is_dir() {
        DirBuilder::new().recursive(true).create(&dir).unwrap();
    }

    Ok(dir)
}

// --------------------------------------------------
fn sketch_files(files: &Vec<PathBuf>) -> Result<(), Box<Error>> {
    if files.len() == 0 {
        return Err(MyError::new("No input files").into());
    }

    for (i, file) in files.iter().enumerate() {
        println!("{}: {}", i, file.display());
    }

    Ok(())
}

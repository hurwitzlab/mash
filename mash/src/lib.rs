extern crate clap;
extern crate csv;
extern crate tempfile;
extern crate walkdir;

use clap::{App, Arg};
use std::collections::HashMap;
use std::error::Error;
use std::process::{Command, Stdio};
use std::{
    env, fmt, fs::{self, DirBuilder, File}, io::{self, Write}, path::{Path, PathBuf},
};
use walkdir::WalkDir;

// --------------------------------------------------
type Record = HashMap<String, String>;

// --------------------------------------------------
#[derive(Debug)]
pub struct Config {
    alias_file: Option<String>,
    distance: u32,
    euc_dist_percent: Option<String>,
    num_threads: u32,
    out_dir: PathBuf,
    query: String,
}

// --------------------------------------------------
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

type MyResult<T> = Result<T, Box<Error>>;

// --------------------------------------------------
pub fn get_args() -> MyResult<Config> {
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
        Some(x) => PathBuf::from(x),
        //_ => None,
        _ => {
            let cwd = env::current_dir()?;
            cwd.join(PathBuf::from("mash-out"))
        }
    };

    let alias = match matches.value_of("alias") {
        Some(x) => Some(x.to_string()),
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

    let config = Config {
        alias_file: alias,
        distance: distance,
        euc_dist_percent: euc_dist_percent,
        num_threads: num_threads,
        out_dir: out_dir,
        query: query,
    };

    Ok(config)
}

// --------------------------------------------------
pub fn run(config: Config) -> MyResult<()> {
    let out_dir = &config.out_dir;
    println!("out_dir = {}", out_dir.display());

    if !out_dir.is_dir() {
        DirBuilder::new().recursive(true).create(&out_dir)?;
    }

    let files = find_files(&config.query)?;
    let sketches = sketch_files(&config, &files)?;

    pairwise_compare(&config, &sketches)?;

    //run_r(&out_dir);

    println!("Done.");

    Ok(())
}

// --------------------------------------------------
fn find_files(path: &str) -> Result<Vec<String>, Box<Error>> {
    let meta = fs::metadata(path)?;

    //     if meta.is_file() {
    //         Ok(vec![PathBuf::from(path)])
    //     } else if meta.is_dir() {
    //         fs::read_dir(path)?
    //             .into_iter()
    //             .filter_map(|e| e.and_then(|e| !e.metadata()?.is_dir()))
    //             .map(|x| x.map(|entry| entry.path()))
    //             .collect()
    //     } else {
    //         Ok(vec![])
    //     }

    let files = if meta.is_file() {
        vec![path.to_owned()]
    } else {
        let mut files = vec![];
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let meta = entry.metadata()?;
            if meta.is_file() {
                files.push(entry.path().display().to_string());
            }
        }
        files
    };

    if files.len() == 0 {
        return Err(MyError::new("No input files").into());
    }

    Ok(files)

    //     let res = if meta.is_file() {
    //         vec![path.to_owned()]
    //     } else {
    //         WalkDir::new(path)
    //             .into_iter()
    //             .filter_map(Result::ok)
    //             .filter(|e| !e.file_type().is_dir())
    //             .map(|e| e.path().display().to_string())
    //             .collect()
    //     };
    //Ok(res)
}

// --------------------------------------------------
fn sketch_files(config: &Config, files: &Vec<String>) -> MyResult<Vec<String>> {
    let sketch_dir = config.out_dir.join(PathBuf::from("sketches"));
    if !sketch_dir.is_dir() {
        DirBuilder::new().recursive(true).create(&sketch_dir)?;
    }

    let mut jobs = vec![];

    for (i, file) in files.iter().enumerate() {
        //let basename = file.file_name().unwrap();
        let buf = PathBuf::from(file);
        let basename = buf.file_name().unwrap();
        let out_file = sketch_dir.join(basename);
        let mash_file = format!("{}.msh", out_file.display());

        println!("{}: {}", i + 1, basename.to_string_lossy());

        if !Path::new(&mash_file).exists() {
            jobs.push(format!(
                "mash sketch -p {} -o {} {}",
                config.num_threads,
                out_file.display(),
                file
            ));
        }
    }

    run_jobs(&jobs, "Sketching files", 8)?;

    let sketches: Vec<String> = WalkDir::new(sketch_dir)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| !e.file_type().is_dir())
        .map(|e| e.path().display().to_string())
        .collect();

    if files.len() != sketches.len() {
        return Err(MyError::new("Failed to create all sketches").into());
    }

    Ok(sketches)
}

// --------------------------------------------------
fn run_jobs(jobs: &Vec<String>, msg: &str, num_concurrent: u32) -> MyResult<()> {
    let num_jobs = jobs.len();

    if num_jobs > 0 {
        println!(
            "{} (# {} job{} @ {})",
            msg,
            num_jobs,
            if num_jobs == 1 { "" } else { "s" },
            num_concurrent
        );

        let mut process = Command::new("parallel")
            .arg("-j")
            .arg(num_concurrent.to_string())
            .arg("--halt")
            .arg("soon,fail=1")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()?;

        {
            let stdin = process.stdin.as_mut().expect("Failed to open stdin");
            stdin
                .write_all(jobs.join("\n").as_bytes())
                .expect("Failed to write to stdin");
        }

        let output = process.wait_with_output().expect("Failed to read stdout");
        println!("{}", String::from_utf8_lossy(&output.stdout));
    }

    Ok(())
}

// --------------------------------------------------
fn pairwise_compare(config: &Config, sketches: &Vec<String>) -> MyResult<()> {
    println!("Comparing {} sketch files", sketches.len());

    let fig_dir = config.out_dir.join(PathBuf::from("figures"));
    if !fig_dir.is_dir() {
        DirBuilder::new().recursive(true).create(&fig_dir)?;
    }

    let sketch_list = fig_dir.join("sketches.txt");
    let tmpfile = File::create(&sketch_list)?;

    for sketch in sketches {
        writeln!(&tmpfile, "{}", sketch).unwrap();
    }

    let all_mash = fig_dir.join(PathBuf::from("all.msh"));
    if all_mash.exists() {
        fs::remove_file(&all_mash)?;
    }

    let all_mash_no_ext = fig_dir.join(PathBuf::from("all"));

    let paste = Command::new("mash")
        .arg("paste")
        .arg("-l")
        .arg(all_mash_no_ext)
        .arg(&sketch_list)
        .output()?;

    if !paste.status.success() {
        return Err(MyError::new("Error Mash paste").into());
    }

    let dist = Command::new("mash")
        .arg("dist")
        .arg("-t")
        .arg(&all_mash)
        .arg(&all_mash)
        .output()?;

    let aliases = match &config.alias_file {
        Some(f) => get_aliases(f.to_string()).ok(),
        None => None,
    };

    let dist_out = fix_mash_distance(&String::from_utf8_lossy(&dist.stdout), aliases);
    let dist_file = fig_dir.join("distance.txt");
    let dist_fh = File::create(&dist_file)?;
    write!(&dist_fh, "{}", dist_out)?;

    Ok(())
}

// --------------------------------------------------
fn fix_mash_distance(s: &str, aliases: Option<Record>) -> String {
    let mut res = vec![];
    for (i, line) in s.split("\n").enumerate() {
        res.push(if i == 0 {
            fix_mash_header(&line, &aliases)
        } else {
            fix_mash_line(&line, &aliases)
        });
    }
    res.join("\n")
}

// --------------------------------------------------
fn fix_mash_header(line: &str, aliases: &Option<Record>) -> String {
    let mut flds: Vec<&str> = line.split("\t").collect();
    flds[0] = "";
    let hdrs: Vec<&str> = flds.iter().map(|f| basename(f, aliases)).collect();
    hdrs.join("\t")
}

// --------------------------------------------------
fn fix_mash_line(line: &str, aliases: &Option<Record>) -> String {
    let mut flds: Vec<&str> = line.split("\t").collect();
    flds[0] = basename(flds[0], aliases);
    flds.join("\t")
}

// --------------------------------------------------
fn basename<'a>(filename: &'a str, aliases: &'a Option<Record>) -> &'a str {
    let mut parts: Vec<&str> = filename.split("/").collect();
    let name = match parts.pop() {
        Some(x) => x,
        None => filename,
    };

    if let Some(a) = aliases {
        match a.get(name) {
            Some(alias) => alias,
            _ => name,
        }
    } else {
        name
    }
}

// --------------------------------------------------
fn get_aliases(alias_file: String) -> Result<Record, io::Error> {
    let alias_fh = File::open(&alias_file)?;
    let mut aliases = HashMap::new();
    let delimiter = match Path::new(&alias_file).extension() {
        Some(ext) => match ext.to_str() {
            Some("csv") => b',',
            _ => b'\t',
        },
        _ => b'\t',
    };
    let mut rdr = csv::ReaderBuilder::new()
        .delimiter(delimiter)
        .from_reader(alias_fh);

    for result in rdr.deserialize() {
        let record: Record = result?;
        let name = record.get("sample_name");
        let alias = record.get("alias");

        match (name, alias) {
            (Some(name), Some(alias)) => {
                aliases.insert(name.to_string(), alias.to_string());
                ()
            }
            _ => println!("Missing sample_name or alias"),
        }
    }

    Ok(aliases)
}

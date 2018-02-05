//
//  ViewController.swift
//  VoiceOut
//
//  Created by Roman on 15/11/2017.
//  Copyright © 2017 voiceout.com.au. All rights reserved.
//

import UIKit
import SoundWave
import MessageUI

class ViewController: UIViewController, UITextFieldDelegate, MFMailComposeViewControllerDelegate  {
    
    enum AudioRecodingState {
        case ready
        case recording
        case recorded
        case playing
        case paused
        
        var audioVisualizationMode: AudioVisualizationView.AudioVisualizationMode {
            switch self {
            case .ready, .recording:
                return .write
            case .paused, .playing, .recorded:
                return .read
            }
        }
    }
    
    @IBOutlet weak var audioVisualizationView: AudioVisualizationView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var btnRec: UIButton!
    @IBOutlet weak var btnPlay: UIButton!
    @IBOutlet weak var btnAttach: UIButton!
    @IBOutlet weak var btnDelete: UIButton!
    
    
    let viewModel = ViewModel()
    
    var currentState: AudioRecodingState = .ready {
        didSet {
            self.audioVisualizationView.audioVisualizationMode = self.currentState.audioVisualizationMode
        }
    }
    
    private var chronometer: Chronometer?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.viewModel.askAudioRecordingPermission()
        
        self.viewModel.audioMeteringLevelUpdate = { [weak self] meteringLevel in
            guard let this = self, this.audioVisualizationView.audioVisualizationMode == .write else {
                return
            }
            this.audioVisualizationView.addMeteringLevel(meteringLevel)
        }
        
        self.viewModel.audioDidFinish = { [weak self] in
            self?.currentState = .recorded
            self?.audioVisualizationView.stop()
            self?.updateUI()
        }
        
        self.initUI()
        self.initWaveGraphic()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: - Init UI
    func initUI() {
        nameTextField.text = String(format: "VoiceOut-%@", getCurrentTime())
        btnRec.isEnabled = true
        btnPlay.isEnabled = false
        btnAttach.isEnabled = false
        btnDelete.isEnabled = false
        
        //Init Audio File name
        AudioRecorderManager.shared.audioFileNamePrefix = nameTextField.text!
        
    }
    
    //MARK: - Init Wave Graphic Property
    func initWaveGraphic() {
        self.audioVisualizationView.meteringLevelBarWidth = 1.0
        self.audioVisualizationView.meteringLevelBarInterItem = 1.0
        self.viewModel.audioVisualizationTimeInterval = TimeInterval(0.05)
    }
    
    func getCurrentTime() -> String {
        let date = Date()
        let calendar = Calendar.current
        
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let hour = calendar.component(.hour, from: date)
        let minutes = calendar.component(.minute, from: date)
        let seconds = calendar.component(.second, from: date)
        
        return String(format:"%d-%d-%d-%d-%d-%d", year, month, day, hour, minutes, seconds)
    }
    
    //MARK: - Update UI
    func updateUI() {
        switch self.currentState {
        case .ready:
            self.btnRec.isEnabled = true
            self.btnRec.setImage(UIImage(named: "rec"), for: .normal)
            self.btnPlay.isEnabled = false
            self.btnPlay.setImage(UIImage(named: "play"), for: .normal)
            self.btnAttach.isEnabled = false
            self.btnAttach.setImage(UIImage(named: "attach"), for: .normal)
            self.btnDelete.isEnabled = false
            self.btnDelete.setImage(UIImage(named: "bin"), for: .normal)
        case .recording:
            self.btnRec.isEnabled = true
            self.btnRec.setImage(UIImage(named: "stop"), for: .normal)
            self.btnPlay.isEnabled = false
            self.btnPlay.setImage(UIImage(named: "play"), for: .normal)
            self.btnAttach.isEnabled = false
            self.btnAttach.setImage(UIImage(named: "attach"), for: .normal)
            self.btnDelete.isEnabled = false
            self.btnDelete.setImage(UIImage(named: "bin"), for: .normal)
        case .recorded:
            self.btnRec.isEnabled = false
            self.btnRec.setImage(UIImage(named: "rec"), for: .normal)
            self.btnPlay.isEnabled = true
            self.btnPlay.setImage(UIImage(named: "play"), for: .normal)
            self.btnAttach.isEnabled = true
            self.btnAttach.setImage(UIImage(named: "attach"), for: .normal)
            self.btnDelete.isEnabled = true
            self.btnDelete.setImage(UIImage(named: "bin"), for: .normal)
        case .playing:
            self.btnRec.isEnabled = false
            self.btnRec.setImage(UIImage(named: "rec"), for: .normal)
            self.btnPlay.isEnabled = true
            self.btnPlay.setImage(UIImage(named: "pause"), for: .normal)
            self.btnAttach.isEnabled = false
            self.btnAttach.setImage(UIImage(named: "attach"), for: .normal)
            self.btnDelete.isEnabled = false
            self.btnDelete.setImage(UIImage(named: "bin"), for: .normal)
        case .paused:
            self.btnRec.isEnabled = false
            self.btnRec.setImage(UIImage(named: "rec"), for: .normal)
            self.btnPlay.isEnabled = true
            self.btnPlay.setImage(UIImage(named: "play"), for: .normal)
            self.btnAttach.isEnabled = true
            self.btnAttach.setImage(UIImage(named: "attach"), for: .normal)
            self.btnDelete.isEnabled = true
            self.btnDelete.setImage(UIImage(named: "bin"), for: .normal)
        }
    }
    
    
    //MARK: - Button Actions
    @IBAction func onRec(_ sender: Any) {
        if self.currentState == .ready {
            self.viewModel.startRecording { [weak self] soundRecord, error in
                if let error = error {
                    self?.showAlert(with: error)
                    return
                }
                
                self?.currentState = .recording
                
                self?.chronometer = Chronometer()
                self?.chronometer?.start()
            }
        } else if self.currentState == .recording {
            self.chronometer?.stop()
            self.chronometer = nil
            
            self.viewModel.currentAudioRecord!.meteringLevels = self.audioVisualizationView.scaleSoundDataToFitScreen()
            self.audioVisualizationView.audioVisualizationMode = .read
            
            do {
                try self.viewModel.stopRecording()
                self.currentState = .recorded
            } catch {
                self.currentState = .ready
                self.showAlert(with: error)
            }
        }
        self.updateUI()
    }
    
    @IBAction func onPlay(_ sender: Any) {
        if self.currentState == .recorded || self.currentState == .paused {
            do {
                let duration = try self.viewModel.startPlaying()
                self.currentState = .playing
                self.audioVisualizationView.meteringLevels = self.viewModel.currentAudioRecord!.meteringLevels
                self.audioVisualizationView.play(for: duration)
            } catch {
                self.showAlert(with: error)
            }
        } else if self.currentState == .playing {
            do {
                try self.viewModel.pausePlaying()
                self.currentState = .paused
                self.audioVisualizationView.pause()
            } catch {
                self.showAlert(with: error)
            }
        }
        self.updateUI()
    }
    
    @IBAction func onAttach(_ sender: Any) {
        //Check to see the device can send email.
        if( MFMailComposeViewController.canSendMail() ) {
            
            let mailComposer = MFMailComposeViewController()
            mailComposer.mailComposeDelegate = self
            
            //Set the subject and message of the email
            mailComposer.setSubject("VoiceOut")
            mailComposer.setMessageBody("This audio was recorded by using VoiceOut. Please check this file. Thank you.", isHTML: false)
            
            if let filePath = self.viewModel.currentAudioRecord?.audioFilePathLocal?.absoluteString {
                
                if let fileData = NSData(contentsOfFile: filePath) {
                    mailComposer.addAttachmentData(fileData as Data, mimeType: "audio/aac", fileName: String(format:"%@.aac", self.nameTextField.text!))
                }
            }
            self.present(mailComposer, animated: true, completion: nil)
        }
    }
    
    @IBAction func onDelete(_ sender: Any) {
        do {
            try self.viewModel.resetRecording()
            self.audioVisualizationView.reset()
            self.currentState = .ready
        } catch {
            self.showAlert(with: error)
        }
        self.updateUI()
    }
    
    //MARK: - UITextField Delegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    //MARK: - MailComposeViewController Delegate
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
    
}


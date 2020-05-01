//
//  ViewController.swift
//  SwiftGoo
//
//  Created by Simon Gladman on 13/04/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController
{
    lazy var toolbar: UIToolbar =
    {
        [unowned self] in
        
        let toolbar = UIToolbar()
        
        let loadBarButtonItem = UIBarButtonItem(
            title: "Load",
            style: .plain,
            target: self,
            action: #selector(ViewController.loadImage))
        
        let resetBarButtonItem = UIBarButtonItem(
            title: "Reset",
            style: .plain,
            target: self,
            action: #selector(ViewController.reset))
        
        let spacer = UIBarButtonItem(
            barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace,
            target: nil,
            action: nil)
        
         toolbar.setItems([loadBarButtonItem, spacer, resetBarButtonItem], animated: true)
        
        return toolbar
    }()
    
    let imageView = OpenGLImageView()
    
    var mona = CIImage(image: UIImage(named: "monalisa.jpg")!)!
    
    var accumulator = CIImageAccumulator(
        extent: CGRect(x: 0, y: 0, width: 640, height: 640),
        format: CIFormat.ARGB8
    )
    
    let warpKernel = CIWarpKernel(source:
        "kernel vec2 gooWarp(float radius, float force,  vec2 location, vec2 direction)" +
        "{ " +
        " float dist = distance(location, destCoord()); " +
        
        "  if (dist < radius)" +
        "  { " +
            
        "     float normalisedDistance = 1.0 - (dist / radius); " +
        "     float smoothedDistance = smoothstep(0.0, 1.0, normalisedDistance); " +
            
        "    return destCoord() + (direction * force) * smoothedDistance; " +
        "  } else { " +
        "  return destCoord();" +
        "  }" +
        "}")!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.darkGray
        imageView.backgroundColor = UIColor.darkGray
    
        view.addSubview(imageView)
        view.addSubview(toolbar)
        
        
        accumulator?.setImage(mona)
        
        imageView.image = accumulator!.image()
    }

    // MARK: Layout
    
    override func viewDidLayoutSubviews()
    {
        toolbar.frame = CGRect(
            x: 0,
            y: view.frame.height - toolbar.intrinsicContentSize.height,
            width: view.frame.width,
            height: toolbar.intrinsicContentSize.height)
        
        imageView.frame = CGRect(
            x: 0,
            y: topLayoutGuide.length + 5,
            width: view.frame.width,
            height: view.frame.height -
                topLayoutGuide.length -
                toolbar.intrinsicContentSize.height - 10)
    }

    
    // MARK: Image loading
    
    @objc func loadImage()
    {
        let imagePicker = UIImagePickerController()
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.isModalInPopover = false
        imagePicker.sourceType = UIImagePickerController.SourceType.savedPhotosAlbum
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    // MARL: Reset
    
    @objc func reset()
    {
        accumulator?.setImage(mona)
        
        imageView.image = accumulator!.image()
    }
    
    // MARK: Touch handling

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        guard let touch = touches.first,
            let coalescedTouches = event?.coalescedTouches(for: touch), imageView.imageExtent.contains(touch.location(in: imageView)) else
        {
            return
        }
        
        for coalescedTouch in coalescedTouches
        {
            let locationInImageY = (imageView.frame.height - coalescedTouch.location(in: imageView).y - imageView.imageExtent.origin.y) / imageView.imageScale
            let locationInImageX = (coalescedTouch.location(in: imageView).x - imageView.imageExtent.origin.x) / imageView.imageScale
            
            let location = CIVector(
                x: locationInImageX,
                y: locationInImageY)
          
            let directionScale = 2 / imageView.imageScale
          
            let direction = CIVector(
                x: (coalescedTouch.previousLocation(in: imageView).x - coalescedTouch.location(in: imageView).x) * directionScale,
                y: (coalescedTouch.location(in: imageView).y - coalescedTouch.previousLocation(in: imageView).y) * directionScale)
          
            let r = max(mona.extent.width, mona.extent.height) / 10
            let radius: CGFloat
            let force: CGFloat
     
            if coalescedTouch.maximumPossibleForce == 0
            {
                force = 0.2
                radius = r
            }
            else
            {
                let normalisedForce = coalescedTouch.force / coalescedTouch.maximumPossibleForce
                force = 0.2 + (normalisedForce * 0.2)
                radius = (r / 2) + (r * normalisedForce)
            }

            let arguments = [radius, force, location, direction] as [Any]
            
            let image = warpKernel.apply(
                extent: accumulator!.image().extent,
                roiCallback:
                {
                    (index, rect) in
                    return rect
            },
                image: accumulator!.image(),
                arguments: arguments)
            
            accumulator!.setImage(image!)
        }
        
        imageView.image = accumulator!.image()
    }
}

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate
{    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            let scale = 1280 / max(image.size.width, image.size.height)
            
            mona = CIImage(
                image: image)!
                .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale])
            
            
            
            accumulator = CIImageAccumulator(
                extent: mona.extent,
                format: CIFormat.ARGB8
            )
            
            accumulator?.setImage(mona)
            imageView.image = accumulator!.image()
        }
        dismiss(animated: true, completion: nil)
    }
}

